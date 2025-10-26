//
//  Logging.swift
//  Lyric Fever
//
//  Created by OpenAI Assistant on 2025-08-30.
//

import OSLog

/// Convenience helpers for constructing loggers that follow the app's subsystem naming convention.
enum AppLoggerFactory {
    private static let subsystem = "com.aviwad.LyricFever"

    /// Builds a logger for the supplied category using the Lyric Fever subsystem.
    /// - Parameter category: Logical grouping for log statements.
    /// - Returns: Configured ``Logger`` instance.
    static func makeLogger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

