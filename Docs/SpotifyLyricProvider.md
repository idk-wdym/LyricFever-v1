# SpotifyLyricProvider

## Purpose
`SpotifyLyricProvider` authenticates with Spotify, enforces macOS Sonoma prerequisites, and downloads time-synchronised lyrics with colour metadata. The service normalises logging, error reporting, and timeout handling for Spotify calls.

## Usage
```swift
let provider = SpotifyLyricProvider()
let result = try await provider.fetchNetworkLyrics(
    trackName: "Antifragile",
    trackID: "0O6u0VJ46W86TxN9wgyqDj",
    currentlyPlayingArtist: "LE SSERAFIM",
    currentAlbumName: "ANTIFRAGILE"
)
```
The helper validates track identifiers, caches access tokens, and throws typed errors if Spotify responds with rate limiting, invalid credentials, or malformed payloads.

## Parameters
- `trackName`: Track title forwarded to Spotify logging for diagnostics.
- `trackID`: Spotify track identifier (must be 22 characters).
- `currentlyPlayingArtist`: Optional artist name used for logging only.
- `currentAlbumName`: Optional album name used for logging only.
- `timeout`: Optional override for the default 8 second timeout (must be positive).

## Errors
- `unsupportedOperatingSystem`: Host is not running macOS 14 or newer.
- `missingCookie`: The `sp_dc` cookie was not extracted during onboarding.
- `localTrackUnsupported`: Spotify does not expose lyrics for local files.
- `rateLimited`: Spotify reported "too many requests".
- `tokenGenerationFailed` and `secretFetchFailed`: Authentication prerequisites failed.
- `requestFailed(underlying:)`: Network or decoding errors (logged via `Logger`).

## Timeout & Cancellation
All network calls run via `AsyncTimeout.run`. The provider maps `AsyncTimeoutError.invalidTimeout` to `SpotifyLyricProviderError.invalidTimeout` and surfaces cancellation to the caller without altering the error semantics.

## Logging
A dedicated `Logger` category (`SpotifyLyricProvider`) records info, warning, and error events with sanitised identifiers so that diagnostics remain actionable without leaking user data.

## Example Tests
The `SpotifyLyricProviderTests` template in `LyricFeverTests` shows how to stub the URL session, inject synthetic responses, and assert timeout and decoding failure paths.
