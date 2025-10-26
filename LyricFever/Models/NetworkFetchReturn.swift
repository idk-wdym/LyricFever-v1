//
//  NetworkFetchReturn.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-06.
//

import OSLog

/// Represents the lyric payload and optional colour metadata returned by a network provider.
struct NetworkFetchReturn {
    private static let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "NetworkFetchReturn")

    let lyrics: [LyricLine]
    let colorData: Int32?

    /// Filters out empty lyric lines and appends an informational "Now Playing" line.
    /// - Parameters:
    ///   - songName: The name of the currently playing song.
    ///   - duration: The track duration in milliseconds.
    /// - Returns: A processed lyric payload suitable for display.
    func processed(withSongName songName: String, duration: Int) -> NetworkFetchReturn {
        let filtered = lyrics.filter { !$0.words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard filtered.count > 1 else {
            NetworkFetchReturn.logger.notice("Skipping lyric post-processing because fewer than two lines were returned.")
            return self
        }

        let nowPlayingLine = LyricLine(startTime: Double(duration + 5000), words: "Now Playing: \(songName)")
        return NetworkFetchReturn(lyrics: filtered + [nowPlayingLine], colorData: colorData)
    }
}

