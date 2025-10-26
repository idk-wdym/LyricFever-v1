//
//  TranslationSessionRequest.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import Translation

extension TranslationSession.Request {
    /// Convenience initializer that maps a ``LyricLine`` into a translation request.
    /// - Parameter lyric: The lyric line being translated.
    init(lyric: LyricLine) {
        self.init(sourceText: lyric.words, clientIdentifier: lyric.id.uuidString)
    }
}
