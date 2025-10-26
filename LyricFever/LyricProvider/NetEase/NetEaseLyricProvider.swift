//
//  NetEaseLyricsProvider.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-06-16.
//

import Foundation
import OSLog
import StringMetric

/// Errors surfaced by ``NetEaseLyricProvider``.
enum NetEaseLyricProviderError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case invalidTimeout
    case invalidQuery
    case noMatch
    case lyricsMissing
    case decodingFailed
    case requestFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "NetEase lyrics require macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Timeout must be greater than zero seconds."
        case .invalidQuery:
            return "Track or artist names were empty after trimming whitespace."
        case .noMatch:
            return "No NetEase match satisfied the similarity requirements."
        case .lyricsMissing:
            return "NetEase did not provide any time-synchronised lyrics."
        case .decodingFailed:
            return "Unable to decode NetEase API response."
        case .requestFailed(let underlying):
            return "NetEase request failed: \(underlying.localizedDescription)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Retry with a timeout greater than zero seconds."
        case .invalidQuery:
            return "Ensure both track and artist names are non-empty."
        case .noMatch:
            return "Adjust the search terms to more closely match the desired track."
        case .lyricsMissing:
            return "Retry later or try a different provider."
        case .decodingFailed:
            return "Retry fetching lyrics or report the malformed payload."
        case .requestFailed:
            return "Verify connectivity or inspect the underlying error for details."
        }
    }
}

/// Provides NetEase lyric fetching with sanitised similarity checks and structured logging.
final class NetEaseLyricProvider: LyricProvider {
    let providerName = "NetEase Lyric Provider"

    private let logger = AppLoggerFactory.makeLogger(category: "NetEaseLyricProvider")
    private let userAgentSession: URLSessioning
    private let defaultTimeout: TimeInterval

    /// Creates a lyric provider with optional session overrides for tests.
    /// - Parameters:
    ///   - session: Session responsible for issuing NetEase requests.
    ///   - timeout: Timeout applied to network calls.
    init(session: URLSessioning? = nil, timeout: TimeInterval = 8.0) {
        if let session {
            self.userAgentSession = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
            ]
            self.userAgentSession = URLSession(configuration: configuration)
        }
        self.defaultTimeout = timeout
    }

    /// Fetches NetEase lyrics for the supplied track metadata.
    /// - Parameters:
    ///   - trackName: Track title used to search NetEase.
    ///   - trackID: Spotify track identifier (unused for NetEase but required by ``LyricProvider``).
    ///   - currentlyPlayingArtist: Artist name from the player.
    ///   - currentAlbumName: Album name from the player.
    /// - Returns: ``NetworkFetchReturn`` describing NetEase lyrics and optional colour metadata.
    func fetchNetworkLyrics(
        trackName: String,
        trackID: String,
        currentlyPlayingArtist: String?,
        currentAlbumName: String?
    ) async throws -> NetworkFetchReturn {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            throw NetEaseLyricProviderError.unsupportedOperatingSystem
        }

        guard defaultTimeout > 0 else {
            throw NetEaseLyricProviderError.invalidTimeout
        }

        guard let currentlyPlayingArtist, let currentAlbumName else {
            throw NetEaseLyricProviderError.invalidQuery
        }

        let sanitizedTrack = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedArtist = currentlyPlayingArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAlbum = currentAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTrack.isEmpty, !sanitizedArtist.isEmpty, !sanitizedAlbum.isEmpty else {
            throw NetEaseLyricProviderError.invalidQuery
        }

        let encodedTrack = sanitizedTrack.replacingOccurrences(of: "&", with: "%26")
        let encodedArtist = sanitizedArtist.replacingOccurrences(of: "&", with: "%26")
        guard let url = URL(string: "https://neteasecloudmusicapi-ten-wine.vercel.app/search?keywords=\(encodedTrack) \(encodedArtist)&limit=1") else {
            throw NetEaseLyricProviderError.requestFailed(underlying: URLError(.badURL))
        }

        logger.info("Searching NetEase for track \(sanitizedTrack, privacy: .public) by \(sanitizedArtist, privacy: .public).")

        do {
            let (searchData, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: URLRequest(url: url))
            }
            let neteaseSearch = try JSONDecoder().decode(NetEaseSearch.self, from: searchData)
            guard let neteaseResult = neteaseSearch.result.songs.first, let neteaseArtist = neteaseResult.artists.first else {
                throw NetEaseLyricProviderError.noMatch
            }

            let similarityChecks = [
                sanitizedTrack.distance(between: neteaseResult.name) > 0.75,
                sanitizedArtist.distance(between: neteaseArtist.name) > 0.75,
                sanitizedAlbum.distance(between: neteaseResult.album.name) > 0.75
            ]

            if similarityChecks.filter({ $0 }).count < 2 {
                logger.notice("NetEase similarity gates rejected track \(neteaseResult.id, privacy: .public).")
                throw NetEaseLyricProviderError.noMatch
            }

            guard let lyricURL = URL(string: "https://neteasecloudmusicapi-ten-wine.vercel.app/lyric?id=\(neteaseResult.id)") else {
                throw NetEaseLyricProviderError.requestFailed(underlying: URLError(.badURL))
            }

            let (lyricData, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: URLRequest(url: lyricURL))
            }
            let neteaseLyrics = try JSONDecoder().decode(NetEaseLyrics.self, from: lyricData)
            guard let lyricText = neteaseLyrics.lrc?.lyric else {
                throw NetEaseLyricProviderError.lyricsMissing
            }

            let cleaned = unescapeHTMLEntities(in: lyricText)
            let parser = LyricsParser(lyrics: cleaned)
            logger.debug("Parsed NetEase lyric payload containing \(parser.lyrics.count, privacy: .public) lines.")

            guard parser.lyrics.last?.startTimeMS != 0.0 else {
                throw NetEaseLyricProviderError.lyricsMissing
            }

            return NetworkFetchReturn(lyrics: parser.lyrics, colorData: nil)
        } catch is CancellationError {
            logger.notice("NetEase lyric fetch cancelled for track \(sanitizedTrack, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw NetEaseLyricProviderError.invalidTimeout
            case .timeoutExceeded:
                throw NetEaseLyricProviderError.requestFailed(underlying: timeout)
            }
        } catch let decoding as DecodingError {
            logger.error("Failed to decode NetEase response: \(decoding.localizedDescription, privacy: .public)")
            throw NetEaseLyricProviderError.decodingFailed
        } catch let providerError as NetEaseLyricProviderError {
            throw providerError
        } catch {
            logger.error("NetEase lyric fetch failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            throw NetEaseLyricProviderError.requestFailed(underlying: error)
        }
    }

    /// NetEase provider exposes a search API for the mass search surface.
    /// - Parameters:
    ///   - trackName: Track title used in the search query.
    ///   - artistName: Artist name used in the search query.
    /// - Returns: ``SongResult`` matches sourced from NetEase.
    func search(trackName: String, artistName: String) async throws -> [SongResult] {
        let sanitizedTrack = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTrack.isEmpty, !sanitizedArtist.isEmpty else {
            throw NetEaseLyricProviderError.invalidQuery
        }

        let encodedTrack = sanitizedTrack.replacingOccurrences(of: "&", with: "%26")
        let encodedArtist = sanitizedArtist.replacingOccurrences(of: "&", with: "%26")
        guard let url = URL(string: "https://neteasecloudmusicapi-ten-wine.vercel.app/search?keywords=\(encodedTrack) \(encodedArtist)&limit=5") else {
            throw NetEaseLyricProviderError.requestFailed(underlying: URLError(.badURL))
        }

        do {
            let (searchData, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: URLRequest(url: url))
            }
            let neteaseSearch = try JSONDecoder().decode(NetEaseSearch.self, from: searchData)

            var results: [SongResult] = []
            for song in neteaseSearch.result.songs {
                guard let firstArtist = song.artists.first,
                      let lyricURL = URL(string: "https://neteasecloudmusicapi-ten-wine.vercel.app/lyric?id=\(song.id)") else { continue }
                do {
                    let (lyricData, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                        try Task.checkCancellation()
                        return try await userAgentSession.data(from: lyricURL)
                    }
                    let neteaseLyrics = try JSONDecoder().decode(NetEaseLyrics.self, from: lyricData)
                    guard let lrcText = neteaseLyrics.lrc?.lyric else { continue }
                    let cleaned = unescapeHTMLEntities(in: lrcText)
                    let parsed = LyricsParser(lyrics: cleaned).lyrics
                    if parsed.last?.startTimeMS == 0.0 { continue }
                    results.append(SongResult(lyricType: "NetEase", songName: song.name, albumName: song.album.name, artistName: firstArtist.name, lyrics: parsed))
                } catch {
                    logger.error("Failed to download NetEase lyrics for song \(song.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            return results
        } catch is CancellationError {
            logger.notice("NetEase mass search cancelled for track \(sanitizedTrack, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw NetEaseLyricProviderError.invalidTimeout
            case .timeoutExceeded:
                throw NetEaseLyricProviderError.requestFailed(underlying: timeout)
            }
        } catch let decoding as DecodingError {
            logger.error("Failed to decode NetEase search response: \(decoding.localizedDescription, privacy: .public)")
            throw NetEaseLyricProviderError.decodingFailed
        } catch {
            logger.error("NetEase search failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            throw NetEaseLyricProviderError.requestFailed(underlying: error)
        }
    }
}

/// MARK: - HTML entity unescape
private func unescapeHTMLEntities(in text: String) -> String {
    var s = text
    s = s.replacingOccurrences(of: "&apos;", with: "'")
    s = s.replacingOccurrences(of: "&quot;", with: "\"")
    s = s.replacingOccurrences(of: "&amp;", with: "&")
    s = s.replacingOccurrences(of: "&lt;", with: "<")
    s = s.replacingOccurrences(of: "&gt;", with: ">")
    s = s.replacingOccurrences(of: "&#39;", with: "'")
    s = s.replacingOccurrences(of: "&#x27;", with: "'")
    s = s.replacingOccurrences(of: "\\\n", with: "\n")
    return s
}
