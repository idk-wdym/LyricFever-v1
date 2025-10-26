# UpdaterService

## Purpose
`UpdaterService` wraps Sparkle's updater controller and provides an asynchronous urgent-update check that respects Sonoma availability, timeout budgets, and structured error handling.

## Usage
```swift
let service = UpdaterService()
let requiresUrgentUpdate = try await service.urgentUpdateExists()
if requiresUrgentUpdate {
    // present upgrade UI
}
```

## Parameters
- `timeout`: Optional argument (default 5 seconds) controlling how long to wait for the urgent-version metadata.

## Errors
- `unsupportedOperatingSystem`: macOS earlier than 14.0.
- `invalidTimeout`: Timeout argument was non-positive.
- `decodingFailed`: The response could not be parsed into a version number.
- `versionCheckFailed(underlying:)`: Networking failures, including `AsyncTimeoutError.timeoutExceeded`.

## Logging
The `UpdaterService` logger category records current versus urgent versions, cancellation, and networking errors so Console traces can identify the failure domain.

## Cancellation & Timeouts
Urgent update checks run within `AsyncTimeout.run` and call `Task.checkCancellation()` so UI callers can cancel a pending version check if the app is closing.

## Tests
See `UpdaterServiceTests` for a mock-session template that validates happy paths, timeout handling, and decoding failures without invoking Sparkle.
