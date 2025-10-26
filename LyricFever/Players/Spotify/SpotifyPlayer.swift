//
//  SpotifyPlayer.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-18.
//

import ScriptingBridge
import AppKit
import OSLog

private let spotifyPlayerLogger = AppLoggerFactory.makeLogger(category: "SpotifyPlayer")

class SpotifyPlayer: @MainActor Player {
    var spotifyScript: SpotifyApplication? = SBApplication(bundleIdentifier: "com.spotify.client")
    var trackID: String? {
        spotifyScript?.currentTrack?.spotifyUrl?.spotifyProcessedUrl()
    }
    
    var albumName: String? {
        spotifyScript?.currentTrack?.album
    }
    var artistName: String? {
        spotifyScript?.currentTrack?.artist
    }
    var trackName: String? {
        spotifyScript?.currentTrack?.name
    }
    
    @MainActor
    var currentTime: TimeInterval? {
        guard let playerPosition = spotifyScript?.playerPosition else {
            return nil
        }
        let viewmodel = ViewModel.shared
        return playerPosition * 1000 + (viewmodel.spotifyConnectDelay ? Double(viewmodel.userDefaultStorage.spotifyConnectDelayCount) : 0) + (viewmodel.animatedDisplay ? 400 : 0) + (viewmodel.airplayDelay ?  -2000 : 0)
    }
    
    var duration: Int? {
        spotifyScript?.currentTrack?.duration
    }
    var isRunning: Bool {
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first != nil {
            return true
        } else {
            return false
        }
    }
    var isPlaying: Bool {
        spotifyScript?.playerState == .playing
    }
    var isAuthorized: Bool {
        guard isRunning else {
            return false
        }
        spotifyPlayerLogger.debug("Spotify player state raw value: \(spotifyScript?.playerState?.rawValue ?? -1, privacy: .public)")
        if spotifyScript?.playerState?.rawValue == 0 {
            return false
        }
        return true
    }
    
    
    @MainActor
    /// Nudges Spotify playback to mitigate desynchronised lyric timestamps.
    func fixSpotifyLyricDrift() async throws {
        try await Task.sleep(nanoseconds: 2000000000)
        if isPlaying {
            spotifyPlayerLogger.info("Invoking Spotify lyric drift correction.")
            spotifyScript?.play?()
        }
    }
    
    var volume: Int {
        spotifyScript?.soundVolume ?? 0
    }
    
    /// Decreases Spotify’s output volume in five-point increments.
    func decreaseVolume() {
        guard let soundVolume = spotifyScript?.soundVolume else {
            return
        }
        spotifyScript?.setSoundVolume?(soundVolume-5)
    }
    /// Increases Spotify’s output volume in five-point increments.
    func increaseVolume() {
        guard let soundVolume = spotifyScript?.soundVolume else {
            return
        }
        spotifyScript?.setSoundVolume?(soundVolume+5)
    }
    /// Sets Spotify’s output volume to a specific value.
    func setVolume(to newVolume: Double) {
        spotifyScript?.setSoundVolume?(Int(newVolume))
    }
    /// Toggles playback.
    func togglePlayback() {
        spotifyScript?.playpause?()
    }
    /// Moves to the previous Spotify track or restarts the current one.
    func rewind() {
        spotifyScript?.previousTrack?()
    }
    /// Advances playback to the next Spotify track.
    func forward() {
        spotifyScript?.nextTrack?()
    }
    
    var artworkImage: NSImage? {
        get async {
            guard let artworkUrlString = spotifyScript?.currentTrack?.artworkUrl, let artworkUrl = URL(string: artworkUrlString) else {
                spotifyPlayerLogger.error("Missing Spotify artwork URL for current track.")
                return nil
            }
            do {
                let artwork = try await URLSession.shared.data(for: URLRequest(url: artworkUrl))
                return NSImage(data: artwork.0)
            } catch {
                spotifyPlayerLogger.error("Failed to download Spotify artwork: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }
    
    /// Brings the Spotify application to the foreground for user interaction.
    func activate() {
        spotifyScript?.activate()
    }
    var currentHoverItem: MenubarButtonHighlight = .activateSpotify
}
