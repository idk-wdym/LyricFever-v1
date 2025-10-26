//
//  MusicBrainzArtworkService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import AppKit
import Foundation
import OSLog

/// Errors surfaced by ``MusicBrainzArtworkService``.
enum MusicBrainzArtworkServiceError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case invalidTimeout
    case requestFailed(underlying: Error)
    case decodingFailed
    case artworkUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "MusicBrainz artwork requires macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Timeout must be greater than zero seconds."
        case .requestFailed(let underlying):
            return "MusicBrainz request failed: \(underlying.localizedDescription)."
        case .decodingFailed:
            return "Unable to decode MusicBrainz response."
        case .artworkUnavailable:
            return "Artwork was not available for the requested MBID."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Retry with a timeout greater than zero seconds."
        case .requestFailed:
            return "Verify connectivity or inspect the underlying error for details."
        case .decodingFailed:
            return "Retry fetching artwork or report the malformed payload."
        case .artworkUnavailable:
            return "Try another release or fallback to player artwork."
        }
    }
}

/// Resolves MusicBrainz artwork URLs and downloads cover art with timeout handling.
enum MusicBrainzArtworkService {
    private static let logger = AppLoggerFactory.makeLogger(category: "MusicBrainzArtworkService")
    private static let defaultTimeout: TimeInterval = 5.0

    /// Finds a release MBID for the supplied album and artist names.
    /// - Parameters:
    ///   - albumName: Album title for the search.
    ///   - artistName: Artist name for the search.
    ///   - timeout: Optional timeout applied to the search call.
    /// - Returns: The matching release MBID if found.
    static func findMbid(albumName: String, artistName: String, timeout: TimeInterval = defaultTimeout) async throws -> String? {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            throw MusicBrainzArtworkServiceError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            throw MusicBrainzArtworkServiceError.invalidTimeout
        }

        let escapedArtist = artistName.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAlbum = albumName.replacingOccurrences(of: "\"", with: "\\\"")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "musicbrainz.org"
        components.path = "/ws/2/release/"
        components.queryItems = [
            URLQueryItem(name: "query", value: "artist:\"\(escapedArtist)\" AND release:\"\(escapedAlbum)\""),
            URLQueryItem(name: "fmt", value: "json")
        ]

        guard let url = components.url else {
            logger.error("Failed to build MusicBrainz lookup URL for artist \(artistName, privacy: .public) and album \(albumName, privacy: .public).")
            throw MusicBrainzArtworkServiceError.requestFailed(underlying: URLError(.badURL))
        }

        do {
            let (data, _) = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await URLSession.shared.data(from: url)
            }
            let response = try JSONDecoder().decode(MusicBrainzReply.self, from: data)
            return response.releases.first?.id
        } catch is CancellationError {
            logger.notice("MusicBrainz MBID lookup cancelled for album \(albumName, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw MusicBrainzArtworkServiceError.invalidTimeout
            case .timeoutExceeded:
                throw MusicBrainzArtworkServiceError.requestFailed(underlying: timeout)
            }
        } catch let decoding as DecodingError {
            logger.error("MusicBrainz MBID lookup failed to decode: \(decoding.localizedDescription, privacy: .public)")
            throw MusicBrainzArtworkServiceError.decodingFailed
        } catch {
            logger.error("MusicBrainz MBID lookup failed: \(error.localizedDescription, privacy: .public)")
            throw MusicBrainzArtworkServiceError.requestFailed(underlying: error)
        }
    }

    /// Builds the artwork URL for a given MusicBrainz release identifier.
    /// - Parameter mbid: The MusicBrainz release identifier.
    /// - Returns: Cover art archive URL if the MBID is valid.
    static func artworkUrl(_ mbid: String) -> URL? {
        URL(string: "https://coverartarchive.org/release/\(mbid)/front")
    }

    /// Downloads the cover art image for the supplied MusicBrainz release identifier.
    /// - Parameters:
    ///   - mbid: The MusicBrainz release identifier.
    ///   - timeout: Optional timeout applied to the download call.
    /// - Returns: ``NSImage`` containing the cover art if available.
    static func artworkImage(for mbid: String, timeout: TimeInterval = defaultTimeout) async throws -> NSImage? {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            throw MusicBrainzArtworkServiceError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            throw MusicBrainzArtworkServiceError.invalidTimeout
        }

        guard let url = artworkUrl(mbid) else {
            logger.error("Artwork URL construction failed for MBID \(mbid, privacy: .public).")
            throw MusicBrainzArtworkServiceError.requestFailed(underlying: URLError(.badURL))
        }

        do {
            let (data, _) = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await URLSession.shared.data(for: URLRequest(url: url))
            }
            guard let image = NSImage(data: data) else {
                throw MusicBrainzArtworkServiceError.artworkUnavailable
            }
            logger.info("Fetched MusicBrainz artwork for MBID \(mbid, privacy: .public).")
            return image
        } catch is CancellationError {
            logger.notice("MusicBrainz artwork download cancelled for MBID \(mbid, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw MusicBrainzArtworkServiceError.invalidTimeout
            case .timeoutExceeded:
                throw MusicBrainzArtworkServiceError.requestFailed(underlying: timeout)
            }
        } catch let decoding as DecodingError {
            logger.error("MusicBrainz artwork decode failed: \(decoding.localizedDescription, privacy: .public)")
            throw MusicBrainzArtworkServiceError.decodingFailed
        } catch let error as MusicBrainzArtworkServiceError {
            throw error
        } catch {
            logger.error("MusicBrainz artwork request failed: \(error.localizedDescription, privacy: .public)")
            throw MusicBrainzArtworkServiceError.requestFailed(underlying: error)
        }
    }
}
