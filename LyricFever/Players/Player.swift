//
//  Player.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-18.
//

import Foundation
import AppKit
import OSLog

private let playerLogger = AppLoggerFactory.makeLogger(category: "Player")

protocol Player {
    // track details
    var albumName: String? { get }
    var artistName: String? { get }
    var trackName: String? { get }
    
    // track timing details
    @MainActor
    var currentTime: TimeInterval? { get }
    var duration: Int? { get }
    
    // player details
    var isAuthorized: Bool { get }
    var isPlaying: Bool { get }
    var isRunning: Bool { get }
    
    // additional menubar functions
    var volume: Int { get }
    
    /// Lowers the output volume by a single device-defined increment.
    func decreaseVolume()
    /// Raises the output volume by a single device-defined increment.
    func increaseVolume()
    /// Sets the player volume to a specific level between the supported bounds.
    func setVolume(to newVolume: Double)
    /// Toggles playback.
    func togglePlayback()
    /// Rewinds playback or restarts the current track, depending on provider support.
    func rewind()
    /// Advances playback to the next track or chapter as supported by the provider.
    func forward()
    
    // fullscreen album art
    @MainActor
    var artworkImage: NSImage? { get async }
//    var artworkImageURL: URL? { get }
    
    /// Activates the underlying media application to ensure menu bar interactions succeed.
    func activate()
    var currentHoverItem: MenubarButtonHighlight { get }
}

extension Player {
    var durationAsTimeInterval: TimeInterval? {
        if let duration {
            return TimeInterval(duration*1000)
        } else {
            return nil
        }
    }
    
    /// Downloads and decodes the artwork image for the supplied URL.
    func artwork(for artworkURL: URL) async -> NSImage? {
        do {
            let artwork = try await URLSession.shared.data(for: URLRequest(url: artworkURL))
            return NSImage(data: artwork.0)
        } catch {
            playerLogger.error("Failed to download artwork: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
