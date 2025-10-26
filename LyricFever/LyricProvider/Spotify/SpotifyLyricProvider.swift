//
//  SpotifyLyricsProvider.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-06-16.
//

import Foundation
import OSLog
import SwiftOTP

struct SpotifyLyrics: Decodable {
    let downloadDate: Date
    let language: String
    let lyrics: [LyricLine]

    enum CodingKeys: String, CodingKey {
        case lines, language, syncType
    }

    init(from decoder: Decoder) throws {
        self.downloadDate = Date.now
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = (try? container.decode(String.self, forKey: .language)) ?? ""
        if let syncType = try? container.decode(String.self, forKey: .syncType), syncType == "LINE_SYNCED", var lyrics = try? container.decode([LyricLine].self, forKey: .lines) {
            self.lyrics = lyrics
        } else {
            self.lyrics = []
        }
    }
}

private struct SpotifySecretPayload: Decodable {
    let latestSecretVersion: Int
    let message: [Int]
}

/// Protocol abstraction to enable mocking URLSession behaviour in tests.
protocol URLSessioning {
    /// Executes a data task for the specified request and returns the response payload.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    /// Downloads data from the provided URL using the standard session pipeline.
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessioning {}

/// Enumerates Spotify lyric provider error cases.
enum SpotifyLyricProviderError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case localTrackUnsupported
    case missingCookie
    case invalidTimeout
    case rateLimited
    case decodingFailed
    case secretFetchFailed
    case tokenGenerationFailed
    case requestFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Spotify lyrics require macOS Sonoma (14.0) or newer."
        case .localTrackUnsupported:
            return "Spotify does not supply lyrics for local files."
        case .missingCookie:
            return "Spotify authentication cookie is missing."
        case .invalidTimeout:
            return "Timeout must be greater than zero seconds."
        case .rateLimited:
            return "Spotify temporarily rate limited lyric requests."
        case .decodingFailed:
            return "Unable to decode Spotify lyric payload."
        case .secretFetchFailed:
            return "Failed to retrieve Spotify authentication secret."
        case .tokenGenerationFailed:
            return "Unable to generate Spotify access token."
        case .requestFailed(let underlying):
            return "Spotify lyric request failed: \(underlying.localizedDescription)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer."
        case .localTrackUnsupported:
            return "Skip local files or upload the track to Spotify."
        case .missingCookie:
            return "Sign into Spotify again from the onboarding flow."
        case .invalidTimeout:
            return "Increase the timeout to a value above zero seconds."
        case .rateLimited:
            return "Retry after a short delay."
        case .decodingFailed:
            return "Retry fetching lyrics or report the malformed payload."
        case .secretFetchFailed:
            return "Check network connectivity and retry secret retrieval."
        case .tokenGenerationFailed:
            return "Retry generating an access token after confirming cookie validity."
        case .requestFailed:
            return "Verify connectivity or inspect the underlying error for details."
        }
    }
}

/// Provides Spotify lyric fetching with authentication, timeout control, and structured logging.
final class SpotifyLyricProvider: LyricProvider {
    let providerName = "Spotify Lyric Provider"

    private let logger = AppLoggerFactory.makeLogger(category: "SpotifyLyricProvider")
    private let userAgentSession: URLSessioning
    private let sharedSession: URLSessioning
    private let defaultTimeout: TimeInterval
    private(set) var accessToken: AccessTokenJSON?

    private var isAccessTokenAlive: Bool {
        guard let expiration = accessToken?.accessTokenExpirationTimestampMs else { return false }
        return expiration > Date().timeIntervalSince1970 * 1000
    }

    /// Creates a lyric provider with optional session overrides for testing.
    /// - Parameters:
    ///   - userAgentSession: The session used for Spotify endpoints. Defaults to a configured URLSession.
    ///   - sharedSession: The shared session used for ancillary requests like secret retrieval.
    ///   - defaultTimeout: Timeout applied to Spotify requests.
    init(
        userAgentSession: URLSessioning? = nil,
        sharedSession: URLSessioning = URLSession.shared,
        defaultTimeout: TimeInterval = 8.0
    ) {
        if let userAgentSession {
            self.userAgentSession = userAgentSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"
            ]
            self.userAgentSession = URLSession(configuration: configuration)
        }
        self.sharedSession = sharedSession
        self.defaultTimeout = defaultTimeout
    }

    @MainActor
    private var secretData: [Int] {
        get async throws {
            guard let url = URL(string: "https://iloveyoulyricfever.github.io/myloveisasecret/mylove.json") else {
                logger.error("Secret fetch failed because the URL was invalid.")
                throw SpotifyLyricProviderError.secretFetchFailed
            }

            do {
                let (data, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                    try Task.checkCancellation()
                    return try await sharedSession.data(from: url)
                }
                let secret = try JSONDecoder().decode(SpotifySecretPayload.self, from: data)
                logger.info("Fetched Spotify secret version \(secret.latestSecretVersion, privacy: .public).")
                return secret.message
            } catch is CancellationError {
                logger.notice("Secret fetch cancelled by caller.")
                throw CancellationError()
            } catch let timeout as AsyncTimeoutError {
                switch timeout {
                case .invalidTimeout:
                    throw SpotifyLyricProviderError.invalidTimeout
                case .timeoutExceeded:
                    throw SpotifyLyricProviderError.requestFailed(underlying: timeout)
                }
            } catch {
                logger.error("Failed to fetch Spotify secret: \(error.localizedDescription, privacy: .public)")
                throw SpotifyLyricProviderError.secretFetchFailed
            }
        }
    }

    /// Generates an authenticated Spotify access token if one is not already cached.
    /// - Parameter timeout: Maximum time allowed for token generation.
    private func ensureAccessToken(timeout: TimeInterval) async throws {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("Spotify lyric access attempted on unsupported macOS version.")
            throw SpotifyLyricProviderError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            logger.error("Access token requested with invalid timeout: \(timeout, privacy: .public)s")
            throw SpotifyLyricProviderError.invalidTimeout
        }

        if isAccessTokenAlive {
            return
        }

        guard !ViewModel.shared.userDefaultStorage.cookie.isEmpty else {
            logger.error("Cannot generate Spotify access token because cookie is missing.")
            throw SpotifyLyricProviderError.missingCookie
        }

        do {
            let serverTimeRequest = URLRequest(url: .init(string: "https://open.spotify.com/api/server-time")!)
            let serverTimeData = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: serverTimeRequest).0
            }
            let serverTime = try JSONDecoder().decode(SpotifyServerTime.self, from: serverTimeData).serverTime

            let currentUnix = Int(Date().timeIntervalSince1970)
            let counter = UInt64(currentUnix / 30)

            let secretCipher = try await secretData
            let processed = secretCipher.enumerated().map { UInt8($1 ^ (UInt8(($0 % 33) + 9))) }
            let processedStr = processed.map { String($0) }.joined()
            guard let utf8Bytes = processedStr.data(using: .utf8) else {
                throw SpotifyLyricProviderError.secretFetchFailed
            }
            let secretBase32 = utf8Bytes.base32EncodedString
            guard let secretData = base32DecodeToData(secretBase32) else {
                throw SpotifyLyricProviderError.secretFetchFailed
            }
            guard let hotp = HOTP(secret: secretData, digits: 6, algorithm: .sha1)?.generate(counter: counter) else {
                throw SpotifyLyricProviderError.tokenGenerationFailed
            }

            let buildVer = "web-player_2025-06-10_1749524883369_eef30f4"
            let buildDate = "2025-06-10"
            let urlString = "https://open.spotify.com/api/token?reason=init&productType=web-player&totp=\(hotp)&totpServer=\(hotp)&totpVer=5&sTime=\(serverTime)&cTime=\(currentUnix)&buildVer={\"\(buildVer)\"}&buildDate={\"\(buildDate)\"}"
            guard let url = URL(string: urlString) else {
                throw SpotifyLyricProviderError.tokenGenerationFailed
            }

            var request = URLRequest(url: url)
            request.setValue("sp_dc=\(ViewModel.shared.userDefaultStorage.cookie)", forHTTPHeaderField: "Cookie")

            let data = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: request).0
            }

            do {
                accessToken = try JSONDecoder().decode(AccessTokenJSON.self, from: data)
                logger.info("Spotify access token generated with expiry \(accessToken?.accessTokenExpirationTimestampMs ?? 0, privacy: .public).")
            } catch {
                logger.error("Failed to decode Spotify access token: \(error.localizedDescription, privacy: .public)")
                if let wrapper = try? JSONDecoder().decode(ErrorWrapper.self, from: data), wrapper.error.code == 401 {
                    UserDefaults().set(false, forKey: "hasOnboarded")
                }
                throw SpotifyLyricProviderError.tokenGenerationFailed
            }
        } catch is CancellationError {
            logger.notice("Spotify access token generation cancelled.")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw SpotifyLyricProviderError.invalidTimeout
            case .timeoutExceeded:
                throw SpotifyLyricProviderError.requestFailed(underlying: timeout)
            }
        } catch let error as SpotifyLyricProviderError {
            throw error
        } catch {
            logger.error("Unexpected error while generating Spotify access token: \(error.localizedDescription, privacy: .public)")
            throw SpotifyLyricProviderError.requestFailed(underlying: error)
        }
    }

    @MainActor
    /// Fetches network lyrics.
    func fetchNetworkLyrics(
        trackName: String,
        trackID: String,
        currentlyPlayingArtist: String? = nil,
        currentAlbumName: String? = nil
    ) async throws -> NetworkFetchReturn {
        guard trackID.count == 22 else {
            throw SpotifyLyricProviderError.localTrackUnsupported
        }

        try await ensureAccessToken(timeout: defaultTimeout)

        guard let accessToken else {
            throw SpotifyLyricProviderError.tokenGenerationFailed
        }

        guard let url = URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackID)?format=json&vocalRemoval=false") else {
            throw SpotifyLyricProviderError.requestFailed(underlying: URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.addValue("Bearer \(accessToken.accessToken)", forHTTPHeaderField: "authorization")

        do {
            let (data, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: request)
            }

            guard !data.isEmpty else {
                logger.notice("Spotify returned empty lyric payload for track \(trackID, privacy: .public).")
                return NetworkFetchReturn(lyrics: [], colorData: nil)
            }

            if String(decoding: data, as: UTF8.self) == "too many requests" {
                throw SpotifyLyricProviderError.rateLimited
            }

            let spotifyParent = try JSONDecoder().decode(SpotifyParent.self, from: data)
            logger.info("Fetched Spotify lyrics for track \(trackID, privacy: .public).")
            return NetworkFetchReturn(lyrics: spotifyParent.lyrics.lyrics, colorData: Int32(spotifyParent.colors.background))
        } catch is CancellationError {
            logger.notice("Spotify lyric fetch cancelled for track \(trackID, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw SpotifyLyricProviderError.invalidTimeout
            case .timeoutExceeded:
                throw SpotifyLyricProviderError.requestFailed(underlying: timeout)
            }
        } catch let error as SpotifyLyricProviderError {
            throw error
        } catch {
            logger.error("Failed to fetch Spotify lyrics: \(error.localizedDescription, privacy: .public)")
            throw SpotifyLyricProviderError.requestFailed(underlying: error)
        }
    }

    /// Parses an internal Spotify search JSON payload and returns a helper describing the matched track.
    /// - Parameter data: JSON data from the Spotify search endpoint.
    /// - Returns: Populated ``AppleMusicHelper`` if parsing succeeded.
    func getDetailsFromSpotifyInternalSearchJSON(data: Data) -> AppleMusicHelper? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let searchV2 = dataDict["searchV2"] as? [String: Any],
               let tracksV2 = searchV2["tracksV2"] as? [String: Any],
               let items = tracksV2["items"] as? [[String: Any]],
               let firstItem = items.first,
               let item = firstItem["item"] as? [String: Any],
               let dataObj = item["data"] as? [String: Any] {

                let trackName: String? = dataObj["name"] as? String
                let trackID: String?  = dataObj["id"] as? String

                let album = dataObj["albumOfTrack"] as? [String: Any]
                let albumName: String? = album?["name"] as? String

                let artistName: String?
                if let artists = dataObj["artists"] as? [String: Any],
                   let artistItems = artists["items"] as? [[String: Any]],
                   let firstArtist = artistItems.first,
                   let profile = firstArtist["profile"] as? [String: Any] {
                    artistName = profile["name"] as? String
                } else {
                    artistName = nil
                }

                if let trackID, let trackName, let albumName, let artistName {
                    logger.info("Parsed Spotify internal search result for track \(trackID, privacy: .public).")
                    return AppleMusicHelper(SpotifyID: trackID, SpotifyName: trackName, SpotifyArtist: artistName, SpotifyAlbum: albumName)
                }
            }
        } catch {
            logger.error("Failed to parse Spotify internal search response: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }

    /// Executes a search using Spotify's internal API and returns the best match for Apple Music integration.
    /// - Parameters:
    ///   - artist: Artist name used to scope the search.
    ///   - track: Track title used to scope the search.
    ///   - album: Optional album title to bias the search.
    /// - Returns: Helper describing the located Spotify track.
    @MainActor
    func searchForTrackForAppleMusic(artist: String, track: String, album: String? = nil) async throws -> AppleMusicHelper? {
        try await ensureAccessToken(timeout: defaultTimeout)
        guard let url = URL(string: "https://api-partner.spotify.com/pathfinder/v2/query") else {
            throw SpotifyLyricProviderError.requestFailed(underlying: URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.addValue("Bearer \(accessToken?.accessToken ?? "")", forHTTPHeaderField: "authorization")

        let sanitizedTrack = track.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)

        let searchTerm: String
        if let sanitizedAlbum, !sanitizedAlbum.isEmpty {
            searchTerm = "\(sanitizedTrack) \(sanitizedAlbum) \(sanitizedArtist)"
        } else {
            searchTerm = "\(sanitizedTrack) \(sanitizedArtist)"
        }

        let body: [String: Any] = [
            "variables": [
                "searchTerm": searchTerm,
                "offset": 0,
                "limit": 1,
                "numberOfTopResults": 1,
                "includeAudiobooks": false,
                "includeArtistHasConcertsField": false,
                "includePreReleases": false,
                "includeLocalConcertsField": false,
                "includeAuthors": false
            ],
            "operationName": "searchDesktop",
            "extensions": [
                "persistedQuery": [
                    "version": 1,
                    "sha256Hash": "d9f785900f0710b31c07818d617f4f7600c1e21217e80f5b043d1e78d74e6026"
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, _) = try await AsyncTimeout.run(seconds: defaultTimeout) {
                try Task.checkCancellation()
                return try await userAgentSession.data(for: request)
            }
            return getDetailsFromSpotifyInternalSearchJSON(data: data)
        } catch is CancellationError {
            logger.notice("Spotify internal search cancelled for term \(searchTerm, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw SpotifyLyricProviderError.invalidTimeout
            case .timeoutExceeded:
                throw SpotifyLyricProviderError.requestFailed(underlying: timeout)
            }
        } catch {
            logger.error("Spotify internal search failed: \(error.localizedDescription, privacy: .public)")
            throw SpotifyLyricProviderError.requestFailed(underlying: error)
        }
    }

    /// Searches for Spotify lyrics to power mass-search functionality.
    /// - Parameters:
    ///   - trackName: The target track name.
    ///   - artistName: The associated artist name.
    /// - Returns: ``SongResult`` array describing candidate matches.
    func search(trackName: String, artistName: String) async throws -> [SongResult] {
        let appleMusicHelper = try await searchForTrackForAppleMusic(artist: artistName, track: trackName)
        guard let appleMusicHelper else {
            logger.error("Spotify search returned no match for track \(trackName, privacy: .public) by \(artistName, privacy: .public).")
            return []
        }
        let spotifyID = appleMusicHelper.SpotifyID
        let lyrics = try await fetchNetworkLyrics(trackName: trackName, trackID: spotifyID)
        guard !lyrics.lyrics.isEmpty else {
            logger.notice("Spotify search produced empty lyrics for track \(spotifyID, privacy: .public).")
            return []
        }
        let songResult = SongResult(
            lyricType: "Spotify",
            songName: appleMusicHelper.SpotifyName,
            albumName: appleMusicHelper.SpotifyAlbum,
            artistName: appleMusicHelper.SpotifyArtist,
            lyrics: lyrics.lyrics
        )
        return [songResult]
    }
}
