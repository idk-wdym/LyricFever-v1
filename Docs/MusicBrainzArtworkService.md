# MusicBrainzArtworkService

## Purpose
`MusicBrainzArtworkService` looks up MusicBrainz release identifiers and downloads cover art while enforcing macOS Sonoma support and per-request timeouts.

## Usage
```swift
if let mbid = try await MusicBrainzArtworkService.findMbid(
    albumName: "Crash",
    artistName: "Charli XCX"
) {
    let image = try await MusicBrainzArtworkService.artworkImage(for: mbid)
}
```

## Parameters
- `albumName` / `artistName`: Search terms used when resolving an MBID. They must be non-empty and already URL encoded if special characters are present.
- `mbid`: Release identifier returned from `findMbid`.
- `timeout`: Optional override for the default 5 second budget.

## Errors
- `unsupportedOperatingSystem`: The host is older than macOS 14.0.
- `invalidTimeout`: Timeout argument was non-positive.
- `requestFailed(underlying:)`: Network failures (including `AsyncTimeoutError.timeoutExceeded`).
- `decodingFailed`: JSON decoding failed.
- `artworkUnavailable`: The cover art archive did not contain image data for the MBID.

## Logging
The service uses the `MusicBrainzArtworkService` logger category so you can correlate MBID lookups, successes, and failures from Console or unified logs.

## Cancellation & Timeouts
Both `findMbid` and `artworkImage(for:)` run within `AsyncTimeout.run` and honour cooperative cancellation via `Task.checkCancellation()`.

## Tests
`MusicBrainzArtworkServiceTests` provides a template for mocking `URLSession` responses and asserting success and timeout paths without performing live network calls.
