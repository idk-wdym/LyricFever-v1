//
//  UpdaterService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import Foundation
import OSLog
import Sparkle

/// Enumerates updater-specific errors.
enum UpdaterServiceError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case invalidTimeout
    case versionCheckFailed(underlying: Error)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Updater requires macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Timeout must be greater than zero seconds."
        case .versionCheckFailed(let underlying):
            return "Failed to check for urgent update: \(underlying.localizedDescription)."
        case .decodingFailed:
            return "Unable to decode urgent version payload."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer."
        case .invalidTimeout:
            return "Retry with a timeout greater than zero seconds."
        case .versionCheckFailed:
            return "Verify connectivity or inspect the underlying error for details."
        case .decodingFailed:
            return "Retry fetching the urgent version metadata."
        }
    }
}

/// Wraps Sparkle update functionality with urgent update checks.
final class UpdaterService {
    private static let logger = AppLoggerFactory.makeLogger(category: "UpdaterService")
    private static let urgentVersionURL = URL(string: "https://raw.githubusercontent.com/aviwad/LyricFeverHomepage/master/urgentUpdateVersion.md")!
    private static let defaultTimeout: TimeInterval = 5.0

    // Sparkle / Update Controller
    let updaterController: SPUStandardUpdaterController

    /// Creates the updater service.
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    /// Indicates whether the remote urgent version exceeds the bundled app version.
    /// - Parameter timeout: Optional timeout for the version check.
    /// - Returns: ``Bool`` indicating whether an urgent update exists.
    @MainActor
    func urgentUpdateExists(timeout: TimeInterval = defaultTimeout) async throws -> Bool {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            throw UpdaterServiceError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            throw UpdaterServiceError.invalidTimeout
        }

        guard let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentVersion = Double(versionString) else {
            throw UpdaterServiceError.decodingFailed
        }

        do {
            let (data, _) = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await URLSession(configuration: .ephemeral).data(for: URLRequest(url: Self.urgentVersionURL))
            }
            guard let urgentString = String(bytes: data, encoding: .utf8), let urgentVersion = Double(urgentString) else {
                throw UpdaterServiceError.decodingFailed
            }

            Self.logger.info("Current version \(currentVersion, privacy: .public); urgent version \(urgentVersion, privacy: .public).")
            return currentVersion < urgentVersion
        } catch is CancellationError {
            Self.logger.notice("Urgent update check cancelled.")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw UpdaterServiceError.invalidTimeout
            case .timeoutExceeded:
                throw UpdaterServiceError.versionCheckFailed(underlying: timeout)
            }
        } catch let error as UpdaterServiceError {
            throw error
        } catch {
            Self.logger.error("Urgent update check failed: \(error.localizedDescription, privacy: .public)")
            throw UpdaterServiceError.versionCheckFailed(underlying: error)
        }
    }
}
