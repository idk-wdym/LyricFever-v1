//
//  Extensions.swift
//  SpotlightLyrics
//
//  Created by Scott Rong on 2017/7/28.
//  Copyright © 2017 Scott Rong. All rights reserved.
//

import Foundation

extension CharacterSet {
    public static let quotes = CharacterSet(charactersIn: "\"'")
}

extension String {
    /// Returns nil when the string is empty, otherwise passes the value through unchanged.
    public func emptyToNil() -> String? {
        return self == "" ? nil : self
    }

    /// Treats whitespace-only strings as nil while preserving meaningful content.
    public func blankToNil() -> String? {
        return self.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? nil : self
    }
}
