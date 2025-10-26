//
//  AppleMusicPlayer.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-18.
//

import ScriptingBridge
import MusicKit
import MediaRemoteAdapter
import AppKit
import OSLog

private let appleMusicPlayerLogger = AppLoggerFactory.makeLogger(category: "AppleMusicPlayer")

class AppleMusicPlayer: Player {
    
    init() {
        musicController.onTrackInfoReceived = { data in
            appleMusicPlayerLogger.info("Received Apple Music track info update.")
            Task { @MainActor in
                self.artworkImage = data.payload.artwork
            }
            // This will only be called for Apple Music events
        }
        musicController.startListening()
    }
    
    let musicController = MediaController(bundleIdentifier: "com.apple.Music")
    var appleMusicScript: MusicApplication? = SBApplication(bundleIdentifier: "com.apple.Music")
    var persistentID: String? {
        appleMusicScript?.currentTrack?.persistentID
    }
    var alternativeID: String? {
        let baseID = (appleMusicScript?.currentTrack?.artist ?? "") + (appleMusicScript?.currentTrack?.name ?? "")
        return baseID.count == 22 ? baseID + "_" : baseID
    }
    
    var albumName: String? {
        appleMusicScript?.currentTrack?.album
    }
    var artistName: String? {
        appleMusicScript?.currentTrack?.artist
    }
    var trackName: String? {
        appleMusicScript?.currentTrack?.name
    }
    
    @MainActor
    var currentTime: TimeInterval? {
        guard let playerPosition = appleMusicScript?.playerPosition else {
            return nil
        }
        let viewmodel = ViewModel.shared
        return playerPosition * 1000 + 400 + (viewmodel.animatedDisplay ? 400 : 0) + (viewmodel.airplayDelay ?  -2000 : 0)
    }
    var duration: Int? {
        guard let seconds = appleMusicScript?.currentTrack?.duration.map(Int.init) else {
            appleMusicPlayerLogger.error("Failed to fetch Apple Music track duration.")
            return nil
        }
        return seconds * 1000
    }
    
    var isAuthorized: Bool {
        guard isRunning else {
            return false
        }
        if appleMusicScript?.playerState?.rawValue == 0 {
            return false
        }
        return true
    }
    var isPlaying: Bool {
        appleMusicScript?.playerState == .playing
    }
    var isRunning: Bool {
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first != nil {
            return true
        } else {
            return false
        }
    }
    
    var volume: Int {
        appleMusicScript?.soundVolume ?? 0
    }
    
    /// Decreases Music’s output volume in five-point increments.
    func decreaseVolume() {
        guard let soundVolume = appleMusicScript?.soundVolume else {
            return
        }
        appleMusicScript?.setSoundVolume?(soundVolume-5)
    }
    /// Increases Music’s output volume in five-point increments.
    func increaseVolume() {
        guard let soundVolume = appleMusicScript?.soundVolume else {
            return
        }
        appleMusicScript?.setSoundVolume?(soundVolume+5)
    }
    /// Sets Music’s output volume to a specific value.
    func setVolume(to newVolume: Double) {
        appleMusicScript?.setSoundVolume?(Int(newVolume))
    }
    /// Toggles playback.
    func togglePlayback() {
        appleMusicScript?.playpause?()
    }
    /// Moves to the previous Music track or restarts the current one.
    func rewind() {
        appleMusicScript?.previousTrack?()
    }
    /// Advances playback to the next Music track.
    func forward() {
        appleMusicScript?.nextTrack?()
    }
    
    var artworkImage: NSImage?
    
//    var artworkImage: NSImage? {
//        guard let artworkImage = (appleMusicScript?.currentTrack?.artworks?().firstObject as? MusicArtwork)?.data else {
//            print("AppleMusicPlayer artworkImage: nil data")
//            return nil
//        }
//        return artworkImage
//    }
    
    /// Brings the Music application to the foreground for user interaction.
    func activate() {
        appleMusicScript?.activate()
    }
    var currentHoverItem: MenubarButtonHighlight = .activateAppleMusic
}
