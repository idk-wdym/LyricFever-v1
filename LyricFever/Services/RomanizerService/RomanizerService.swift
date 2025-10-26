//
//  RomanizerService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import Foundation
import IPADic
import Mecab_Swift
import NaturalLanguage
import OpenCC
import OSLog

/// Enumerates the recoverable romanization and transliteration errors.
enum RomanizerServiceError: LocalizedError, Equatable {
    case unsupportedOperatingSystem
    case emptyInput
    case tokenizerUnavailable
    case conversionFailed
    case invalidTimeout
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Romanization requires macOS Sonoma (14.0) or newer."
        case .emptyInput:
            return "The provided text is empty after trimming whitespace."
        case .tokenizerUnavailable:
            return "The Japanese tokenizer is not available."
        case .conversionFailed:
            return "Failed to convert the provided text into the requested script."
        case .invalidTimeout:
            return "The timeout must be greater than zero seconds."
        case .timeoutExceeded:
            return "The romanization or transliteration request exceeded the allowed time."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "Update to macOS Sonoma (14.0) or newer to enable romanization features."
        case .emptyInput:
            return "Provide non-empty text for conversion."
        case .tokenizerUnavailable:
            return "Ensure the IPADic dictionary is bundled correctly."
        case .conversionFailed:
            return "Verify the text uses a supported language and try again."
        case .invalidTimeout:
            return "Increase the timeout to a value greater than zero seconds."
        case .timeoutExceeded:
            return "Retry with a higher timeout or reduce the amount of text to convert."
        }
    }
}

/// Provides sanitized romanization and transliteration helpers with timeout, cancellation, and logging.
enum RomanizerService {
    private static let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "RomanizerService")
    private static let defaultTimeout: TimeInterval = 1.5

    /// Generates a romanized representation of a lyric line.
    /// - Parameters:
    ///   - lyric: The lyric to romanize.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: A latin-script representation of the lyric.
    /// - Throws: ``RomanizerServiceError`` or ``CancellationError`` when conversion fails.
    static func generateRomanizedLyric(_ lyric: LyricLine, timeout: TimeInterval = defaultTimeout) async throws -> String {
        try await generateRomanizedString(lyric.words, timeout: timeout)
    }

    /// Generates a romanized representation of the supplied text.
    /// - Parameters:
    ///   - string: The string to romanize.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: The latin-script representation of the provided string.
    /// - Throws: ``RomanizerServiceError`` or ``CancellationError`` when conversion fails.
    static func generateRomanizedString(_ string: String, timeout: TimeInterval = defaultTimeout) async throws -> String {
        let sanitized = try validatePreconditions(for: string, timeout: timeout)
        logger.debug("Romanizing string of length \(sanitized.count, privacy: .public).")

        do {
            return try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()

                if let language = NLLanguageRecognizer.dominantLanguage(for: sanitized), language == .japanese {
                    return try romanizeJapanese(text: sanitized)
                }

                guard let converted = sanitized.applyingTransform(.toLatin, reverse: false), !converted.isEmpty else {
                    throw RomanizerServiceError.conversionFailed
                }
                return converted
            }
        } catch is CancellationError {
            logger.notice("Romanization cancelled for string of length \(sanitized.count, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw RomanizerServiceError.invalidTimeout
            case .timeoutExceeded:
                throw RomanizerServiceError.timeoutExceeded
            }
        } catch let error as RomanizerServiceError {
            logger.error("Romanization failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch {
            logger.error("Romanization failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            throw RomanizerServiceError.conversionFailed
        }
    }

    /// Converts the lyric into the simplified Chinese script preferred in mainland China.
    /// - Parameters:
    ///   - lyric: The lyric to transliterate.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: A simplified Chinese representation of the lyric.
    static func generateMainlandTransliteration(_ lyric: LyricLine, timeout: TimeInterval = defaultTimeout) async throws -> String {
        try await transliterateChinese(lyric: lyric, style: .mainlandSimplified, timeout: timeout)
    }

    /// Converts the lyric into a region-neutral traditional Chinese script.
    /// - Parameters:
    ///   - lyric: The lyric to transliterate.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: A traditional Chinese representation of the lyric.
    static func generateTraditionalNeutralTransliteration(_ lyric: LyricLine, timeout: TimeInterval = defaultTimeout) async throws -> String {
        try await transliterateChinese(lyric: lyric, style: .traditionalNeutral, timeout: timeout)
    }

    /// Converts the lyric into the Hong Kong traditional Chinese script.
    /// - Parameters:
    ///   - lyric: The lyric to transliterate.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: A Hong Kong variant traditional Chinese representation of the lyric.
    static func generateHongKongTransliteration(_ lyric: LyricLine, timeout: TimeInterval = defaultTimeout) async throws -> String {
        try await transliterateChinese(lyric: lyric, style: .hongKong, timeout: timeout)
    }

    /// Converts the lyric into the Taiwan traditional Chinese script.
    /// - Parameters:
    ///   - lyric: The lyric to transliterate.
    ///   - timeout: Optional timeout controlling how long the operation may take.
    /// - Returns: A Taiwan variant traditional Chinese representation of the lyric.
    static func generateTaiwanTransliteration(_ lyric: LyricLine, timeout: TimeInterval = defaultTimeout) async throws -> String {
        try await transliterateChinese(lyric: lyric, style: .taiwan, timeout: timeout)
    }

    /// Validates preconditions.
    private static func validatePreconditions(for string: String, timeout: TimeInterval) throws -> String {
        guard ProcessInfo.processInfo.isRunningOnSonomaOrNewer else {
            logger.error("Romanization requested on unsupported macOS version.")
            throw RomanizerServiceError.unsupportedOperatingSystem
        }

        guard timeout > 0 else {
            logger.error("Romanization requested with invalid timeout: \(timeout, privacy: .public)s")
            throw RomanizerServiceError.invalidTimeout
        }

        let sanitized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            logger.error("Romanization requested for empty input text.")
            throw RomanizerServiceError.emptyInput
        }
        return sanitized
    }

    /// Romanizes japanese.
    private static func romanizeJapanese(text: String) throws -> String {
        do {
            let tokenizer = try Tokenizer(dictionary: IPADic())
            let tokens = tokenizer.tokenize(text: text, transliteration: .romaji)
            guard !tokens.isEmpty else {
                logger.error("Japanese tokenization produced no tokens.")
                throw RomanizerServiceError.conversionFailed
            }
            return tokens.map { $0.reading }.joined()
        } catch {
            logger.error("Failed to initialise Japanese tokenizer: \(error.localizedDescription, privacy: .public)")
            throw RomanizerServiceError.tokenizerUnavailable
        }
    }

    /// Transliterates a lyric line into romanized Chinese using the requested style and timeout guard.
    private static func transliterateChinese(lyric: LyricLine, style: ChineseTransliterationStyle, timeout: TimeInterval) async throws -> String {
        let sanitized = try validatePreconditions(for: lyric.words, timeout: timeout)
        logger.debug("Transliterating string of length \(sanitized.count, privacy: .public) using style \(style.logDescription).")

        do {
            return try await AsyncTimeout.run(seconds: timeout) {
                try Task.checkCancellation()
                let converter = try ChineseConverter(options: style.options)
                return converter.convert(sanitized)
            }
        } catch is CancellationError {
            logger.notice("Chinese transliteration cancelled for string of length \(sanitized.count, privacy: .public).")
            throw CancellationError()
        } catch let timeout as AsyncTimeoutError {
            switch timeout {
            case .invalidTimeout:
                throw RomanizerServiceError.invalidTimeout
            case .timeoutExceeded:
                throw RomanizerServiceError.timeoutExceeded
            }
        } catch let error as RomanizerServiceError {
            logger.error("Chinese transliteration failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch {
            logger.error("Chinese transliteration failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            throw RomanizerServiceError.conversionFailed
        }
    }
}

private enum ChineseTransliterationStyle {
    case mainlandSimplified
    case traditionalNeutral
    case hongKong
    case taiwan

    var options: ChineseConverter.Options {
        switch self {
        case .mainlandSimplified:
            return [.simplify]
        case .traditionalNeutral:
            return [.traditionalize]
        case .hongKong:
            return [.traditionalize, .hkStandard]
        case .taiwan:
            return [.traditionalize, .twStandard, .twIdiom]
        }
    }

    var logDescription: StaticString {
        switch self {
        case .mainlandSimplified:
            return "simplified"
        case .traditionalNeutral:
            return "traditionalNeutral"
        case .hongKong:
            return "hongKong"
        case .taiwan:
            return "taiwan"
        }
    }
}
