# LRCLIB Lyric Provider

## Purpose
The LRCLIB Lyric Provider retrieves lyrics from the LRCLIB REST API using validated metadata, Sonoma compatibility checks, and structured logging.

## Usage
### Fetching lyrics for the currently playing track
```swift
Task { @MainActor in
    do {
        let result = try await lrclibProvider.fetchNetworkLyrics(
            trackName: trackName,
            trackID: trackID,
            currentlyPlayingArtist: artist,
            currentAlbumName: album
        )
        handle(result)
    } catch {
        logger.error("LRCLIB fetch failed: \(error.localizedDescription)")
    }
}
```

### Searching for matching tracks
```swift
Task {
    do {
        let matches = try await lrclibProvider.search(trackName: "Dynamite", artistName: "BTS")
        logger.info("LRCLIB returned \(matches.count) matches")
    } catch {
        logger.error("LRCLIB search failed: \(error.localizedDescription)")
    }
}
```

## Parameters
- `trackName` / `artistName` / `currentAlbumName`: Metadata strings used to build LRCLIB queries.
- `trackID`: Identifier used for logging and downstream persistence.
- `timeout`: Configurable per-provider at initialization (default `8.0` seconds).

## Preconditions
- macOS Sonoma (14.0) or newer is required.
- Track, artist, and album metadata must be non-empty after trimming whitespace.

## Error Handling
`LRCLIBLyricProvider` throws `LRCLIBLyricProviderError`:
- `.unsupportedOperatingSystem`
- `.missingTrackMetadata`
- `.requestConstructionFailed`
- `.networkFailure(underlying:)`
- `.decodingFailed(underlying:)`

## Examples
### Customising the request timeout
```swift
let provider = LRCLIBLyricProvider(timeout: 5.0)
```

## Performance Notes
- Requests run against an `URLSession` configured with per-request timeouts and LRCLIB-specific user-agent headers.
- Logging via `OSLog` captures request metadata counts without exposing raw lyric content.
- Input validation prevents unnecessary network calls when metadata is incomplete.

## Rollback Plan
- Revert `LRCLIBLyricProvider.swift` to remove the structured error handling and timeout configuration.
- Delete `LRCLIBLyricProviderTests.swift` if the provider returns to its legacy synchronous behaviour.
- Restore any callers that depended on silent failures instead of thrown errors.
