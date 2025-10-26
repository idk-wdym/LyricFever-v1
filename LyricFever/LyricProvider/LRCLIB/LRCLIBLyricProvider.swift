//
//  LRCLIBLyricProvider.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-06-16.
//

import Foundation
import OSLog

/// Structured failure cases for the LRCLIB lyric provider.
enum LRCLIBLyricProviderError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case missingTrackMetadata
    case requestConstructionFailed
    case networkFailure(underlying: Error)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "LRCLIB requests require macOS Sonoma (14.0) or newer."
        case .missingTrackMetadata:
            return "Artist, album, or track metadata is missing."
        case .requestConstructionFailed:
            return "Unable to construct a valid LRCLIB request URL."
        case .networkFailure(let underlying):
            return "Failed to download lyrics: \(underlying.localizedDescription)."
        case .decodingFailed(let underlying):
            return "Unable to decode LRCLIB response: \(underlying.localizedDescription)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer and retry."
        case .missingTrackMetadata:
            return "Provide track, artist, and album metadata before requesting lyrics."
        case .requestConstructionFailed:
            return "Verify the track metadata is URL-safe or retry later."
        case .networkFailure:
            return "Check your network connection and retry."
        case .decodingFailed:
            return "Ensure the service returns valid JSON or file a support ticket."
        }
    }
}

/// Fetches lyric content from the LRCLIB API with validated inputs, timeouts, and structured logging.
final class LRCLIBLyricProvider: LyricProvider {
    private let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "LRCLIBLyricProvider")
    private let session: URLSession
    private let requestTimeout: TimeInterval

    var providerName = "LRCLIB Lyric Provider"

    /// Creates a provider configured with LRCLIB-specific user-agent headers and request timeouts.
    /// - Parameters:
    ///   - timeout: Request timeout applied to LRCLIB calls.
    ///   - session: Optional custom session for dependency injection during testing.
    init(timeout: TimeInterval = 8.0, session: URLSession? = nil) {
        requestTimeout = timeout
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            configuration.httpAdditionalHeaders = [
                "User-Agent": "Lyric Fever v3.2 (https://github.com/aviwad/LyricFever)"
            ]
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
    }

    /// Fetches lyrics for the currently playing track from LRCLIB.
    /// - Parameters:
    ///   - trackName: The current track title.
    ///   - trackID: The unique track identifier.
    ///   - currentlyPlayingArtist: The artist name of the track.
    ///   - currentAlbumName: The album title of the track.
    /// - Returns: Network results including lyric lines and optional colour metadata.
    func fetchNetworkLyrics(
        trackName: String,
        trackID: String,
        currentlyPlayingArtist: String?,
        currentAlbumName: String?
    ) async throws -> NetworkFetchReturn {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("LRCLIB requested on unsupported macOS version.")
            throw LRCLIBLyricProviderError.unsupportedOperatingSystem
        }

        let sanitizedTrack = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let artist = currentlyPlayingArtist?.trimmingCharacters(in: .whitespacesAndNewlines),
              let album = currentAlbumName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sanitizedTrack.isEmpty,
              !artist.isEmpty,
              !album.isEmpty else {
            logger.error("LRCLIB request missing required metadata (track/artist/album).")
            throw LRCLIBLyricProviderError.missingTrackMetadata
        }

        guard let url = makeComponents(
            path: "/api/get",
            items: [
                URLQueryItem(name: "artist_name", value: artist),
                URLQueryItem(name: "track_name", value: sanitizedTrack),
                URLQueryItem(name: "album_name", value: album)
            ]
        ).url else {
            logger.error("Failed to assemble LRCLIB /api/get request URL.")
            throw LRCLIBLyricProviderError.requestConstructionFailed
        }

        logger.info("LRCLIB /api/get request prepared for track \(sanitizedTrack, privacy: .public).")

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        do {
            let (data, _) = try await session.data(for: request)
            let lyrics = try JSONDecoder().decode(LRCLIBLyrics.self, from: data)
            logger.info("LRCLIB returned \(lyrics.lyrics.count, privacy: .public) lyric lines for track \(trackID, privacy: .public).")
            return NetworkFetchReturn(lyrics: lyrics.lyrics, colorData: nil)
        } catch let error as DecodingError {
            logger.error("Failed to decode LRCLIB response for track \(trackID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw LRCLIBLyricProviderError.decodingFailed(underlying: error)
        } catch {
            logger.error("LRCLIB request failed for track \(trackID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw LRCLIBLyricProviderError.networkFailure(underlying: error)
        }
    }

    /// Searches LRCLIB for a track given the song and artist names.
    /// - Parameters:
    ///   - trackName: The track title.
    ///   - artistName: The artist performing the track.
    /// - Returns: Candidate lyric results from LRCLIB.
    func search(trackName: String, artistName: String) async throws -> [SongResult] {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("LRCLIB search requested on unsupported macOS version.")
            throw LRCLIBLyricProviderError.unsupportedOperatingSystem
        }

        let sanitizedTrack = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedTrack.isEmpty, !sanitizedArtist.isEmpty else {
            logger.error("LRCLIB search missing track or artist metadata.")
            throw LRCLIBLyricProviderError.missingTrackMetadata
        }

        guard let url = makeComponents(
            path: "/api/search",
            items: [
                URLQueryItem(name: "track_name", value: sanitizedTrack),
                URLQueryItem(name: "artist_name", value: sanitizedArtist)
            ]
        ).url else {
            logger.error("Failed to assemble LRCLIB /api/search request URL.")
            throw LRCLIBLyricProviderError.requestConstructionFailed
        }

        logger.info("LRCLIB /api/search request prepared for track \(sanitizedTrack, privacy: .public) by \(sanitizedArtist, privacy: .public).")

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        do {
            let (data, _) = try await session.data(for: request)
            let results = try JSONDecoder().decode(PluralLRCLIBLyrics.self, from: data)
            logger.info("LRCLIB search returned \(results.lyrics.count, privacy: .public) candidate tracks.")
            return results.lyrics.map {
                SongResult(
                    lyricType: "LRCLIB",
                    songName: $0.trackName,
                    albumName: $0.albumName,
                    artistName: $0.artistName,
                    lyrics: $0.lyrics
                )
            }
        } catch let error as DecodingError {
            logger.error("Failed to decode LRCLIB search response: \(error.localizedDescription, privacy: .public)")
            throw LRCLIBLyricProviderError.decodingFailed(underlying: error)
        } catch {
            logger.error("LRCLIB search request failed: \(error.localizedDescription, privacy: .public)")
            throw LRCLIBLyricProviderError.networkFailure(underlying: error)
        }
    }

    /// Builds a URLComponents instance for LRCLIB endpoints.
    /// - Parameters:
    ///   - path: API path component.
    ///   - items: Query items to append.
    /// - Returns: Configured URL components pointing to LRCLIB.
    func makeComponents(path: String, items: [URLQueryItem]) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = path
        components.queryItems = items
        return components
    }
}
