//
//  ColorDataService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import CoreData
import Foundation
import OSLog

@MainActor
/// Enumerates the structured error cases emitted when persisting colour mappings fails.
enum ColorDataServiceError: LocalizedError, Equatable {
    case invalidTrackIdentifier
    case unsupportedOperatingSystem
    case invalidTimeout
    case persistentStoreUnavailable
    case timeoutExceeded
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidTrackIdentifier:
            return "The track identifier is empty or contains unsupported characters."
        case .unsupportedOperatingSystem:
            return "Color persistence requires macOS Sonoma (14.0) or newer."
        case .persistentStoreUnavailable:
            return "The color database is not currently available."
        case .timeoutExceeded:
            return "Saving the color mapping exceeded the allowed time."
        case .invalidTimeout:
            return "The supplied timeout must be greater than zero."
        case .saveFailed(let underlying):
            return "Failed to store the color mapping: \(underlying.localizedDescription)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidTrackIdentifier:
            return "Provide a valid track identifier before attempting to save."
        case .unsupportedOperatingSystem:
            return "Update macOS to Sonoma (14.0) or newer and retry."
        case .persistentStoreUnavailable:
            return "Reinitialise the persistent store or restart the app."
        case .timeoutExceeded:
            return "Retry the operation when the system is less busy."
        case .invalidTimeout:
            return "Pass a timeout value greater than zero seconds."
        case .saveFailed:
            return "Check the persistent store logs for additional details."
        }
    }
}

@MainActor
/// Provides validated persistence of track colour metadata to Core Data with logging and timeout protection.
final class ColorDataService {
    private static let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "ColorDataService")
    private static let defaultTimeout: TimeInterval = 2.0

    /// Saves the resolved background colour for a track to Core Data with validation, logging, and timeout handling.
    /// - Parameters:
    ///   - trackID: The persistent identifier for the currently playing track.
    ///   - songColor: The colour value to persist.
    ///   - context: Optional override for the managed object context.
    ///   - timeout: The maximum time, in seconds, to wait before cancelling the operation.
    /// - Throws: ``ColorDataServiceError`` when validation, availability, or persistence fails.
    static func saveColorToCoreData(
        trackID: String,
        songColor: Int32,
        context: NSManagedObjectContext? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws {
        let sanitizedTrackID = trackID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTrackID.isEmpty else {
            logger.error("Refusing to persist colour because the track identifier is empty.")
            throw ColorDataServiceError.invalidTrackIdentifier
        }

        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("Refusing to persist colour because macOS Sonoma or newer is required.")
            throw ColorDataServiceError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            logger.error("Refusing to persist colour because the timeout \(timeout, privacy: .public)s is non-positive.")
            throw ColorDataServiceError.invalidTimeout
        }

        let activeContext = context ?? ViewModel.shared.coreDataContainer.viewContext

        guard let coordinator = activeContext.persistentStoreCoordinator, !coordinator.persistentStores.isEmpty else {
            logger.error("Refusing to persist colour because the persistent store is unavailable.")
            throw ColorDataServiceError.persistentStoreUnavailable
        }

        logger.info("Persisting colour \(songColor, privacy: .public) for track \(sanitizedTrackID, privacy: .public).")

        do {
            try await AsyncTimeout.run(seconds: timeout) {
                try await persistColor(trackID: sanitizedTrackID, songColor: songColor, context: activeContext)
            }
            logger.info("Successfully persisted colour for track \(sanitizedTrackID, privacy: .public).")
        } catch let timeoutError as AsyncTimeoutError {
            switch timeoutError {
            case .invalidTimeout:
                logger.error("Colour persistence rejected due to invalid timeout argument.")
                throw ColorDataServiceError.invalidTimeout
            case .timeoutExceeded:
                logger.error("Colour persistence timed out for track \(sanitizedTrackID, privacy: .public).")
                throw ColorDataServiceError.timeoutExceeded
            }
        } catch let error as ColorDataServiceError {
            logger.error("Colour persistence failed for track \(sanitizedTrackID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        } catch {
            logger.error("Colour persistence failed for track \(sanitizedTrackID, privacy: .public) with unexpected error: \(error.localizedDescription, privacy: .public)")
            throw ColorDataServiceError.saveFailed(underlying: error)
        }
    }

    /// Persists the colour mapping for the supplied track on the provided context.
    /// - Parameters:
    ///   - trackID: Sanitised identifier for the track.
    ///   - songColor: The resolved colour value for the track.
    ///   - context: The managed object context used for persistence.
    private static func persistColor(trackID: String, songColor: Int32, context: NSManagedObjectContext) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let mapping = IDToColor(context: context)
                    mapping.id = trackID
                    mapping.songColor = songColor
                    if context.hasChanges {
                        try context.save()
                    } else {
                        ColorDataService.logger.log("No context changes detected when attempting to persist colour.")
                    }
                    continuation.resume()
                } catch {
                    context.rollback()
                    ColorDataService.logger.error("Rolling back colour persistence for track \(trackID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: ColorDataServiceError.saveFailed(underlying: error))
                }
            }
        }
    }

}
