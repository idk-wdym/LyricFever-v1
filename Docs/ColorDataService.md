# Color Data Service

## Purpose
The Color Data Service persists the resolved background colour for a track so the UI can immediately reuse the cached value when the song reappears. The service validates inputs, enforces macOS Sonoma compatibility, and records structured logs for observability.

## Usage
### Persisting a colour mapping
```swift
Task { @MainActor in
    do {
        try await ColorDataService.saveColorToCoreData(
            trackID: trackIdentifier,
            songColor: resolvedColour,
            timeout: 2.0
        )
    } catch {
        // Surface the failure to the caller and offer remediation.
        logger.error("Colour cache persistence failed: \(error.localizedDescription)")
    }
}
```

## Parameters
- `trackID`: A non-empty identifier that uniquely references the current track.
- `songColor`: The resolved ARGB colour value to persist.
- `context`: Optional `NSManagedObjectContext` override. Defaults to the shared `ViewModel` context.
- `timeout`: Optional timeout in seconds (default: `2.0`). The operation is cancelled if exceeded.

## Preconditions
- macOS Sonoma (14.0) or newer must be running. Earlier versions throw `ColorDataServiceError.unsupportedOperatingSystem`.
- The persistent store must be loaded and writable.
- The caller must execute on the main actor to respect `@MainActor` semantics of the service.

## Error Handling
`ColorDataService.saveColorToCoreData` throws `ColorDataServiceError`:
- `.invalidTrackIdentifier` – the provided identifier was empty after trimming.
- `.unsupportedOperatingSystem` – the host OS predates macOS Sonoma.
- `.persistentStoreUnavailable` – the persistent container is not ready.
- `.invalidTimeout` – the provided timeout value was zero or negative.
- `.timeoutExceeded` – the save operation exceeded the configured timeout.
- `.saveFailed(underlying:)` – Core Data returned an unexpected error during `save()`.

Each error includes a recovery suggestion surfaced via `LocalizedError`.

## Examples
### Handling timeouts explicitly
```swift
Task { @MainActor in
    do {
        try await ColorDataService.saveColorToCoreData(
            trackID: trackIdentifier,
            songColor: resolvedColour,
            timeout: 0.5
        )
    } catch ColorDataServiceError.timeoutExceeded {
        // Retry with exponential back-off or fall back to transient storage.
    } catch {
        // Report and continue without cached colours.
    }
}
```

## Performance Notes
- Saving runs on the Core Data context queue to avoid blocking the main thread.
- Timeout enforcement adds a lightweight `Task.sleep` watchdog (~8 bytes per call) and cancels immediately upon completion.
- Structured logging (`OSLog`) is asynchronous and incurs negligible overhead relative to Core Data I/O.
