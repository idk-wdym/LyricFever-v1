# NetEaseLyricProvider

## Purpose
`NetEaseLyricProvider` supplies a validated fallback lyric source. It sanitises queries, enforces Sonoma compatibility, and performs similarity checks so that accidental mismatches do not overwrite existing lyrics.

## Usage
```swift
let provider = NetEaseLyricProvider()
let result = try await provider.fetchNetworkLyrics(
    trackName: "Drama",
    trackID: "placeholder-track-id",
    currentlyPlayingArtist: "aespa",
    currentAlbumName: "Drama"
)
```
When calling `search(trackName:artistName:)`, the provider returns `SongResult` records suitable for the mass-search experience.

## Parameters
- `trackName`, `trackID`, `currentlyPlayingArtist`, `currentAlbumName`: Track metadata used to build search queries; the provider throws `invalidQuery` if the fields are empty after trimming.
- `timeout`: Optional override for the 8 second timeout budget used by both search and lyric downloads.

## Errors
- `unsupportedOperatingSystem`: macOS earlier than 14.0.
- `invalidTimeout`: Timeout argument was non-positive.
- `invalidQuery`: Required metadata fields were empty.
- `noMatch`: Similarity heuristics filtered the response list.
- `lyricsMissing`: NetEase responded without time-synchronised lyric data.
- `decodingFailed`: JSON payloads failed to decode.
- `requestFailed(underlying:)`: Transport failures captured and logged.

## Timeout & Cancellation
The service uses `AsyncTimeout.run` for each HTTP call and propagates `CancellationError` so the UI may cancel long-running fetches without leaking resources.

## Logging
The `NetEaseLyricProvider` logger reports query lifecycle events, rejected matches, and decoding failures. Identifiers are emitted with `.public` privacy so release builds redact them as needed.

## Example Tests
`NetEaseLyricProviderTests` demonstrates how to inject a mock session, assert similarity guardrails, and cover both `fetchNetworkLyrics` and `search` branches with cancellation scenarios.
