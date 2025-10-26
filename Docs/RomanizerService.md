# Romanizer Service

## Purpose
The Romanizer Service converts lyric lines and metadata into romanized or region-specific Chinese scripts. It validates inputs, enforces macOS Sonoma compatibility, and records structured logs for diagnostics.

## Usage
### Romanizing currently playing lyrics
```swift
Task {
    do {
        let romanized = try await RomanizerService.generateRomanizedLyric(currentLyric)
        logger.info("Romanized lyric: \(romanized)")
    } catch {
        logger.error("Romanization failed: \(error.localizedDescription)")
    }
}
```

### Converting to Simplified Chinese
```swift
Task {
    do {
        let simplified = try await RomanizerService.generateMainlandTransliteration(currentLyric)
        logger.info("Simplified lyric: \(simplified)")
    } catch {
        logger.error("Chinese conversion failed: \(error.localizedDescription)")
    }
}
```

## Parameters
- `lyric`: A `LyricLine` containing the lyric text and timestamp.
- `string`: Plain text to romanize outside of lyric contexts.
- `timeout`: Optional timeout (seconds) for the conversion. Defaults to `1.5` seconds.

## Preconditions
- macOS Sonoma (14.0) or newer is required (`ProcessInfo.processInfo.isRunningOnSonomaOrNewer`).
- The provided text must be non-empty after trimming whitespace.
- Timeouts must be positive; zero or negative values throw `RomanizerServiceError.invalidTimeout`.

## Error Handling
`RomanizerService` throws `RomanizerServiceError`:
- `.unsupportedOperatingSystem` – host OS predates Sonoma.
- `.emptyInput` – sanitised input is empty.
- `.tokenizerUnavailable` – IPADic tokenizer initialisation failed.
- `.conversionFailed` – the text could not be converted to the target script.
- `.invalidTimeout` – the provided timeout is zero or negative.
- `.timeoutExceeded` – the request exceeded the allowed runtime.

## Examples
### Skipping empty lyrics when romanizing in bulk
```swift
for lyric in lyrics {
    do {
        let romanized = try await RomanizerService.generateRomanizedLyric(lyric)
        cache.append(romanized)
    } catch RomanizerServiceError.emptyInput {
        continue
    }
}
```

## Performance Notes
- Conversion runs within a timeout-guarded asynchronous task to avoid blocking the main actor.
- Tokenizer creation is scoped per request to avoid shared-state contention while keeping memory overhead low.
- Structured logging via `OSLog` is asynchronous and does not block lyric rendering.

## Rollback Plan
- Revert `RomanizerService.swift` and the associated ViewModel changes to restore the previous synchronous implementation.
- Remove the new tests (`RomanizerServiceTests.swift`) and documentation sections if the service reverts to legacy behaviour.
- Clear derived data to ensure no stale Swift concurrency artifacts remain after rollback.
