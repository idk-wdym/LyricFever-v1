//
//  TranslationService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import NaturalLanguage
import OSLog
import Translation

/// Structured failure modes emitted by ``TranslationService``.
enum TranslationServiceError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case emptyRequest
    case invalidTimeout
    case cancelled
    case timeoutExceeded
    case translationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Translation requires macOS Sonoma (14.0) or newer."
        case .emptyRequest:
            return "No lyrics were provided for translation."
        case .invalidTimeout:
            return "The timeout must be greater than zero seconds."
        case .cancelled:
            return "The translation request was cancelled."
        case .timeoutExceeded:
            return "The translation request exceeded the allowed time."
        case .translationFailed(let underlying):
            return "Translation failed with error: \(underlying.localizedDescription)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer and try again."
        case .emptyRequest:
            return "Ensure that lyrics are loaded before requesting a translation."
        case .invalidTimeout:
            return "Pass a timeout greater than zero seconds."
        case .cancelled:
            return "Retry the translation when the task is active."
        case .timeoutExceeded:
            return "Retry with a higher timeout budget or on a faster connection."
        case .translationFailed:
            return "Inspect the underlying error or retry after checking connectivity."
        }
    }
}

/// Protocol describing the subset of ``TranslationSession`` used by the service to enable mocking in tests.
protocol TranslationSessioning {
    /// Requests translations for the provided lyric segments from the underlying session.
    func translations(from request: [TranslationSession.Request]) async throws -> [TranslationSession.Response]
}

extension TranslationSession: TranslationSessioning {}

/// Centralises translation requests with validation, timeout handling, and structured logging.
enum TranslationService {
    private static let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "TranslationService")
    private static let defaultTimeout: TimeInterval = 8.0

    /// Executes a translation request while enforcing operating-system requirements, cancellation, and timeout handling.
    /// - Parameters:
    ///   - session: The translation session used to generate responses.
    ///   - request: The set of lyric requests to translate.
    ///   - timeout: The maximum amount of time to wait for the translation.
    /// - Returns: ``TranslationResult`` describing the outcome of the translation attempt.
    static func translationTask(
        _ session: TranslationSessioning,
        request: [TranslationSession.Request],
        timeout: TimeInterval = defaultTimeout
    ) async -> TranslationResult {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("Translation attempted on unsupported macOS version.")
            return .failure(.unsupportedOperatingSystem)
        }

        guard timeout > 0 else {
            logger.error("Translation requested with invalid timeout: \(timeout, privacy: .public)s")
            return .failure(.invalidTimeout)
        }

        let sanitizedRequests = request.filter { !$0.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !sanitizedRequests.isEmpty else {
            logger.error("Translation requested with no non-empty lyric content.")
            return .failure(.emptyRequest)
        }

        do {
            let responses = try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                return try await session.translations(from: sanitizedRequests)
            }
            logger.info("Successfully generated translations for \(responses.count, privacy: .public) lyric lines.")
            return .success(responses)
        } catch is CancellationError {
            logger.notice("Translation task cancelled by caller.")
            return .failure(.cancelled)
        } catch let timeoutError as AsyncTimeoutError {
            switch timeoutError {
            case .invalidTimeout:
                return .failure(.invalidTimeout)
            case .timeoutExceeded:
                return .failure(.timeoutExceeded)
            }
        } catch {
            if let language = findRealLanguage(for: sanitizedRequests) {
                logger.error("Translation requires configuration update for language \(language.identifier, privacy: .public).")
                return .needsConfigUpdate(language)
            }

            logger.error("Translation failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            return .failure(.translationFailed(underlying: error))
        }
    }

    /// Attempts to infer the dominant language from the supplied translation requests.
    /// - Parameter translationRequest: The lyric requests associated with a translation attempt.
    /// - Returns: The detected language if present in the dataset.
    static func findRealLanguage(for translationRequest: [TranslationSession.Request]) -> Locale.Language? {
        var languageOccurrences: [Locale.Language: Int] = [:]
        let recognizer = NLLanguageRecognizer()

        for lyric in translationRequest {
            recognizer.reset()
            recognizer.processString(lyric.sourceText)
            guard let dominantLanguage = recognizer.dominantLanguage else {
                continue
            }

            let localeLanguage = Locale.Language(identifier: dominantLanguage.rawValue)
            if localeLanguage != Locale.Language.systemLanguages.first {
                languageOccurrences[localeLanguage, default: 0] += 1
            }
        }

        guard let mostCommon = languageOccurrences.max(by: { $0.value < $1.value }), mostCommon.value >= 3 else {
            logger.notice("Unable to determine dominant source language for translation request.")
            return nil
        }

        logger.info("Detected dominant source language: \(mostCommon.key.identifier, privacy: .public)")
        return mostCommon.key
    }
}
