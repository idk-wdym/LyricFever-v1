//
//  SpotifyLyricsInMenubarApp.swift
//  SpotifyLyricsInMenubar
//
//  Created by Avi Wadhwa on 26/07/23.
//

import SwiftUI
import Translation
import LaunchAtLogin
import OSLog

extension NSScreen {
    static var mainWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1920
    }
    static var mainHeight: CGFloat {
        NSScreen.main?.frame.height ?? 1080
    }
}

enum MusicType {
    case spotify
    case appleMusic
}

@main
struct LyricFever: App {
    @State var viewmodel = ViewModel.shared
    @Environment(\.openWindow) var openWindow
    @Environment(\.openURL) var openURL
    private let logger = AppLoggerFactory.makeLogger(category: "LyricFeverApp")
    
    var body: some Scene {
        MenuBarExtra {
            MenubarWindowView()
                .environment(\.colorScheme, .dark)
                .preferredColorScheme(.dark)
                .environment(viewmodel)
        } label: {
            // Text(Image) Doesn't render propertly in MenubarExtra. Stupid Apple. Must resort to if/else
            MenubarLabelView()
                .environment(viewmodel)
            .task(id: viewmodel.currentlyPlaying) {
                if viewmodel.currentlyPlaying == nil {
                    logger.warning("Ignored artwork fetch because currentlyPlaying is nil.")
                    return
                }
                do {
                    logger.info("Fetching artwork image for currently playing track change.")
                    if let artworkImage = await viewmodel.currentPlayerInstance.artworkImage {
                        logger.info("Fetched artwork from player APIs.")
                        viewmodel.artworkImage = artworkImage
                    } else if let artistName = viewmodel.currentlyPlayingArtist, let currentAlbumName = viewmodel.currentAlbumName {
                        if let mbid = await MusicBrainzArtworkService.findMbid(albumName: currentAlbumName, artistName: artistName) {
                            viewmodel.artworkImage = await MusicBrainzArtworkService.artworkImage(for: mbid)
                        }
                    } else {
                        logger.warning("Unable to resolve artwork image via player or MusicBrainz.")
                    }
                } catch {
                    logger.error("Artwork fetch failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            .task(id: viewmodel.userDefaultStorage.latestUpdateWindowShown) {
                if viewmodel.userDefaultStorage.latestUpdateWindowShown < 24 {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "update")
                    viewmodel.userDefaultStorage.latestUpdateWindowShown = 24
                }
            }
            .task(id: viewmodel.userDefaultStorage.hasOnboarded) {
                if !viewmodel.userDefaultStorage.hasOnboarded {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                } else {
                    guard !viewmodel.isFirstFetch else {
                        logger.notice("Skipping onboarding refresh because first fetch has not completed.")
                        return
                    }
                    // make refreshLyrics use the same Task<> that fetch(_) uses
                    do {
                        try await viewmodel.refreshLyrics()
                    } catch {
                        logger.error("Refresh lyrics failed during onboarding task: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .onChange(of: viewmodel.showLyrics) {
                viewmodel.toggleLyrics()
            }
            .floatingPanel(isPresented: $viewmodel.displayKaraoke) {
                KaraokeView()
                    .animation(.easeIn(duration: 0.2))
                    .environment(viewmodel)
            }
            .onAppear {
                viewmodel.onAppear(openWindow)
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.apple.Music.playerInfo"))) { notification in
                viewmodel.appleMusicPlaybackDidChange(notification)
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.spotify.client.PlaybackStateChanged"))) { notification in
                viewmodel.spotifyPlaybackDidChange(notification)
            }
            .translationTask(viewmodel.translationSessionConfig) { session in
                await viewmodel.translationTask(session)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                viewmodel.saveKaraokeFontOnTermination()
            }
            .onChange(of: viewmodel.translationSourceLanguage) {
                // don't call reloadTranslationConfigIfTranslating(), that invalidates when config is the same
                if viewmodel.userDefaultStorage.translate {
                    viewmodel.translationSessionConfig = TranslationSession.Configuration(source: viewmodel.translationSourceLanguage, target: viewmodel.userLocaleLanguage)
                }
            }
            .onChange(of: viewmodel.userLocaleLanguage) {
                viewmodel.reloadTranslationConfigIfTranslating()
            }
            .onChange(of: viewmodel.userDefaultStorage.chinesePreference) {
                viewmodel.chinesePreferenceDidChange()
            }
            .onChange(of: viewmodel.userDefaultStorage.romanize) {
                viewmodel.romanizeDidChange()
            }
//            .onChange(of: viewmodel.userDefaultStorage.romanizeMetadata) {
//                if viewmodel.userDefaultStorage.romanizeMetadata {
//                    viewmodel.romanizeMetadata()
//                }
//            }
            .onChange(of: viewmodel.userDefaultStorage.translate) {
                if !viewmodel.reloadTranslationConfigIfTranslating() {
                    viewmodel.translatedLyric = []
                }
            }
            .onChange(of: viewmodel.currentPlayer) {
                logger.notice("Resetting onboarding status due to player change.")
                viewmodel.userDefaultStorage.hasOnboarded = false
            }
            .onChange(of: viewmodel.fullscreen) {
                if viewmodel.fullscreen {
                    openWindow(id: "fullscreen")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            .onChange(of: viewmodel.userDefaultStorage.hasOnboarded) {
                if viewmodel.userDefaultStorage.hasOnboarded {
                    viewmodel.didOnboard()
                } else {
                    viewmodel.stopLyricUpdater()
                }
            }
            .onChange(of: viewmodel.userDefaultStorage.translate) {
                viewmodel.openTranslationHelpOnFirstRun(openURL)
            }
            .onChange(of: viewmodel.userDefaultStorage.cookie) {
                viewmodel.spotifyLyricProvider.accessToken = nil
            }
            .onChange(of: viewmodel.isPlaying) {
                if viewmodel.isPlaying, viewmodel.showLyrics, viewmodel.userDefaultStorage.hasOnboarded {
                    if !viewmodel.currentlyPlayingLyrics.isEmpty  {
                        logger.info("Starting lyric updater due to Spotify change with non-empty lyrics.")
                        viewmodel.startLyricUpdater()
                    }
                } else {
                    viewmodel.stopLyricUpdater()
                }
            }
            .task(id: viewmodel.currentlyPlayingAppleMusicPersistentID) {
                if viewmodel.currentlyPlayingAppleMusicPersistentID != nil {
                    logger.info("Triggering Apple Music starter for new persistent ID.")
                    await viewmodel.appleMusicStarter()
                }
            }
            .onChange(of: viewmodel.currentlyPlaying) {
                logger.info("Detected song change event from player.")
                Task {
                    await viewmodel.onCurrentlyPlayingIDChange()
                }
            }
        }
        .menuBarExtraStyle(.window)
        Window("Lyric Fever: Fullscreen", id: "fullscreen") {
            FullscreenView()
                .windowFullScreenBehavior(.enabled)
                .preferredColorScheme(.dark)
                .environment(viewmodel)
                .onAppear {
                    // Block "Esc" button
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
                            if aEvent.keyCode == 53 { // if esc pressed
                                return nil
                            }
                            return aEvent
                        }
                    Task { @MainActor in
                        let window = NSApp.windows.first {$0.identifier?.rawValue == "fullscreen"}
                        window?.collectionBehavior = .fullScreenPrimary
                        if window?.styleMask.rawValue != 49167 {
                            window?.toggleFullScreen(true)
                        }
                    }
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                    viewmodel.fullscreen = false
                }
        }
        .defaultSize(width: NSScreen.mainWidth, height: NSScreen.mainHeight)
        Window("Lyric Fever: Onboarding", id: "onboarding") { // << here !!
            OnboardingWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 600, maxHeight: 600, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        Window("Lyric Fever: Searching for \(viewmodel.currentlyPlayingName ?? "-") by \(viewmodel.currentlyPlayingArtist ?? "-")", id: "search") {
            SearchWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 500, maxHeight: 500, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        Window("Lyric Fever: Update 2.3", id: "update") { // << here !!
            UpdateWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 500, maxHeight: 500, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
            .windowLevel(.floating)
    }
}


extension String {
  // https://gist.github.com/budidino/8585eecd55fd4284afaaef762450f98e
    @MainActor
    /// Truncates the string to the configured lyric length and appends the trailing marker if needed.
    func trunc(length: Int? = nil, trailing: String = "…") -> String {
        let length = length ?? ViewModel.shared.userDefaultStorage.truncationLength
        return (self.count > length) ? self.prefix(length) + trailing : self
    }
}

