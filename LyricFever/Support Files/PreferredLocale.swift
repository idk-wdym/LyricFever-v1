//
//  ProcessLocale.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import Foundation


// https://stackoverflow.com/questions/48136456/locale-current-reporting-wrong-language-on-device
extension Locale {
    /// Resolves the display string for the user’s preferred system language.
    static func preferredLocaleString() -> String? {
        guard let preferredIdentifier = Locale.preferredLanguages.first else {
            return Locale.current.localizedString(for: Calendar.autoupdatingCurrent.identifier)
        }
        return Locale.current.localizedString(forIdentifier: preferredIdentifier)
    }
    /// Returns a locale configured with the first user-preferred language identifier.
    static func preferredLocale() -> Locale {
        guard let preferredIdentifier = Locale.preferredLanguages.first else {
            return Locale.current
        }
        return Locale.init(identifier: preferredIdentifier)
    }
}
