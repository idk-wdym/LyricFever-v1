//
//  TranslationResult.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import Translation

/// Describes the outcome of a translation request.
enum TranslationResult {
    /// The translation completed successfully with the supplied responses.
    case success([TranslationSession.Response])
    /// The translation failed because a more specific configuration is required for the detected language.
    case needsConfigUpdate(Locale.Language)
    /// The translation failed with a structured error.
    case failure(TranslationServiceError)
}
