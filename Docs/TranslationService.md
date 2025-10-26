# Translation Service

## Purpose
The Translation Service orchestrates lyric translation through Apple’s Translation framework while enforcing macOS Sonoma compatibility, input validation, and timeout handling.

## Usage
### Translating the current lyric batch
```swift
Task { @MainActor in
    let request = lyrics.map { TranslationSession.Request(lyric: $0) }
    let result = await TranslationService.translationTask(session, request: request)

    switch result {
    case .success(let responses):
        translatedLyrics = responses.map(\.$targetText)
    case .needsConfigUpdate(let language):
        translationConfig = TranslationSession.Configuration(source: language, target: targetLanguage)
    case .failure(let error):
        logger.error("Translation failed: \(error.localizedDescription)")
    }
}
```

## Parameters
- `session`: A `TranslationSessioning` instance (e.g. `TranslationSession`).
- `request`: An array of `TranslationSession.Request` values produced from lyrics.
- `timeout`: Optional timeout (seconds) for the translation. Defaults to `8.0` seconds.

## Preconditions
- macOS Sonoma (14.0) or newer is required.
- Requests must contain at least one non-empty lyric (`TranslationServiceError.emptyRequest`).
- Timeout values must be positive.

## Error Handling
`TranslationService` returns `TranslationResult`:
- `.success(responses)` – translation completed.
- `.needsConfigUpdate(language)` – a dominant language was detected and configuration should be updated.
- `.failure(error)` – translation failed with `TranslationServiceError`:
  - `.unsupportedOperatingSystem`
  - `.emptyRequest`
  - `.invalidTimeout`
  - `.cancelled`
  - `.timeoutExceeded`
  - `.translationFailed(underlying:)`

## Examples
### Retrying after a timeout with back-off
```swift
var attempt = 0
repeat {
    attempt += 1
    let result = await TranslationService.translationTask(session, request: request, timeout: 4.0 * Double(attempt))
    if case .success = result { break }
    try await Task.sleep(for: .seconds(Double(attempt)))
} while attempt < 3
```

## Performance Notes
- Translation requests run within a timeout wrapper to prevent runaway tasks.
- The service logs outcomes through `OSLog` for observability without blocking the UI.
- Filtering empty lyrics before submission reduces load on the Translation framework.

## Rollback Plan
- Revert `TranslationService.swift`, `TranslationResult.swift`, and related ViewModel updates to restore the legacy behaviour.
- Remove `TranslationServiceTests.swift` and the accompanying documentation section if rolling back.
- Reset translation session configuration caching to ensure stale values from the new flow are cleared.
