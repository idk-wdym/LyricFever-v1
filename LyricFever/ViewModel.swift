//
//  viewModel.swift
//  SpotifyLyricsInMenubar
//
//  Created by Avi Wadhwa on 14/08/23.
//

import Foundation
#if os(macOS)
#endif
@preconcurrency import CoreData
import AmplitudeSwift
import SwiftUI
import MediaPlayer
import OSLog
#if os(macOS)
import WebKit
import Translation
import KeyboardShortcuts
#endif

private let colorDataLogger = Logger(subsystem: "com.aviwad.LyricFever", category: "ViewModel.ColorPersistence")
private let translationLogger = Logger(subsystem: "com.aviwad.LyricFever", category: "ViewModel.Translation")
private let romanizationLogger = Logger(subsystem: "com.aviwad.LyricFever", category: "ViewModel.Romanization")
private let chineseConversionLogger = Logger(subsystem: "com.aviwad.LyricFever", category: "ViewModel.ChineseConversion")

@MainActor
@Observable class ViewModel {
    static let shared = ViewModel()
    var currentlyPlaying: String?

    var currentVolume: Int = 0

    var artworkImage: NSImage?
    var currentArtworkURL: URL?

    var duration: Int = 0
    var currentTime = CurrentTimeWithStoredDate(currentTime: 0)

    private let logger = AppLoggerFactory.makeLogger(category: "ViewModel")

    /// Routes diagnostic payloads through the shared view-model logger.
    private func log(_ items: Any..., separator: String = " ", terminator: String = "\n", level: OSLogType = .default) {
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        logger.log(level: level, "\(message, privacy: .public)")
    }

    var formattedCurrentTime: String {
        let baseTime = currentTime.currentTime
        let totalSeconds = Int(baseTime) / 1000
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: TimeInterval(totalSeconds)) ?? "0:00"
    }
    
    /// Formats the elapsed playback time relative to the supplied date snapshot.
    func formattedCurrentTime(for date: Date) -> String {
        let baseTime = currentTime.currentTime
        let delta = date.timeIntervalSince(currentTime.storedDate)
//        log("Formatted Current Time: delta is \(delta)")
        let totalSeconds = Int((baseTime + delta) / 1000)
//        log("total seconds should be \(totalSeconds)")
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: TimeInterval(totalSeconds)) ?? "0:00"
    }
    
    var formattedDuration: String {
        let totalSeconds = duration / 1000
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: TimeInterval(totalSeconds)) ?? "0:00"
    }
    
    #if os(macOS)
    var updaterService = UpdaterService()
    var appleMusicPlayer = AppleMusicPlayer()
    var spotifyPlayer = SpotifyPlayer()
    #else
    var currentTab = TabType.nowPlaying
    var spotifyPlayer = TVSpotifyPlayer()
    var hasWebApiOnboarded = false
    #endif
    
    var currentPlayerInstance: Player {
        #if os(macOS)
        switch currentPlayer {
            case .appleMusic:
                return appleMusicPlayer
            case .spotify:
                return spotifyPlayer
        }
        #else
        return spotifyPlayer
        #endif
    }
    
    #if os(macOS)
    var translationSessionConfig: TranslationSession.Configuration?
    #endif
    var userDefaultStorage = UserDefaultStorage()
    
    #if os(macOS)
    // Karaoke Font
    var karaokeFont: NSFont
    
    // nil to deal with previously saved songs that don't have lang saved with them
    // or for LRCLIB
    var currentBackground: Color? = nil
    
    var animatedDisplay: Bool {
        get {
            displayKaraoke || fullscreen
        }
        set {
            
        }
    }
    
    var canDisplayLyrics: Bool {
        showLyrics && !lyricsIsEmptyPostLoad
    }

    var displayKaraoke: Bool {
        get {
            showLyrics && isPlaying && userDefaultStorage.karaoke && !karaokeModeHovering && (currentlyPlayingLyricsIndex != nil)
        }
        set {
            
        }
    }
    var displayFullscreen: Bool {
        get {
            fullscreen
        }
        set {
            if fullscreen {
                NSApp.windows.first {$0.identifier?.rawValue == "fullscreen"}?.makeKeyAndOrderFront(self)
                NSApplication.shared.activate(ignoringOtherApps: true)
            } else {
                fullscreen = true
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    var currentlyPlayingAppleMusicPersistentID: String? = nil
    #endif
    
    var currentlyPlayingName: String?
    var currentlyPlayingArtist: String?
    var currentAlbumName: String?
    var currentlyPlayingLyrics: [LyricLine] = []
    var currentlyPlayingLyricsIndex: Int?
    var isPlaying: Bool = false
    var romanizedLyrics: [String] = []
    var chineseConversionLyrics: [String] = []
    var translatedLyric: [String] = []
    var showLyrics = true
    #if os(macOS)
    var fullscreen = false
    var spotifyConnectDelay: Bool = false
    var airplayDelay: Bool = false
    #endif
    var isFetchingTranslation = false
    var translationExists: Bool { !translatedLyric.isEmpty}
    
    // CoreData container (for saved lyrics)
    let coreDataContainer: NSPersistentContainer
    
    // Logging / Analytics
    let amplitude = Amplitude(configuration: .init(apiKey: amplitudeKey))
    
    var isHearted = false
    
    // Async Tasks (Lyrics fetch, Apple Music -> Spotify ID fetch, Lyrics Updater)
    private var currentFetchTask: Task<[LyricLine], Error>?
    private var currentLyricsUpdaterTask: Task<Void,Error>?
    private var currentLyricsDriftFix: Task<Void,Error>?
    var isFetching = false
    private var currentAppleMusicFetchTask: Task<Void,Error>?
    private var romanizationTask: Task<Void, Never>?
    private var chineseConversionTask: Task<Void, Never>?
    
    // Songs are translated to user locale
    let systemLocale: Locale
    let systemLocaleString: String
    var translationSourceLanguage: Locale.Language?
//    var translationTargetLanguage: Locale.Language?
    var userLocaleLanguage: Locale.Language {
        if let translationTargetLanguage = userDefaultStorage.translationTargetLanguage {
            return translationTargetLanguage
        } else {
            return systemLocale.language
        }
    }
    var userLocaleLanguageString: String {
        if let translationTargetLanguage = userDefaultStorage.translationTargetLanguage, let translationTargetLanguageString = Locale.current.localizedString(forIdentifier: translationTargetLanguage.minimalIdentifier) {
            return translationTargetLanguageString
        } else {
            return systemLocaleString
        }
    }

    // Override menubar with an update message
    var mustUpdateUrgent: Bool = false

    // Delayed variable to hook onto for fullscreen (whether to display lyrics or not)
    // Prevents flickering that occurs when we directly bind to currentlyPlayingLyrics.isEmpty()
    var lyricsIsEmptyPostLoad: Bool = true
    
    #if os(macOS)
    // UI element used to hide if karaokeModeHoveringSetting is true
    var karaokeModeHovering: Bool = false
    
    var colorBinding: Binding<Color> {
        Binding<Color> {
            Color(NSColor(hexString: self.userDefaultStorage.fixedKaraokeColorHex)!)
        } set: { newValue in
            self.userDefaultStorage.fixedKaraokeColorHex = NSColor(newValue).hexString!
        }
    }
    #endif
    
    #if os(macOS)
    var currentPlayer: PlayerType {
        get {
            if self.userDefaultStorage.spotifyOrAppleMusic {
                return .appleMusic
            } else {
                return .spotify
            }
        } set {
            if newValue == .appleMusic {
                self.userDefaultStorage.spotifyOrAppleMusic = true
            } else {
                self.userDefaultStorage.spotifyOrAppleMusic = false
            }
        }
    }
    #else
    @ObservationIgnored var currentPlayer: Player {
        return spotifyPlayer
    }
    #endif
    
    var currentDuration: Int? {
        currentPlayerInstance.duration
    }
    var isPlayerRunning: Bool {
        currentPlayerInstance.isRunning
    }
    #if os(macOS)
    var currentAlbumArt: Color {
        guard userDefaultStorage.karaokeUseAlbumColor, let currentBackground else {
            return colorBinding.wrappedValue
        }
        return currentBackground
    }
    #endif
    
    var spotifyLyricProvider = SpotifyLyricProvider()
    var lRCLyricProvider = LRCLIBLyricProvider()
    var netEaseLyricProvider = NetEaseLyricProvider()
    #if os(macOS)
    var localFileUploadProvider = LocalFileUploadProvider()
    #endif
    @ObservationIgnored lazy var allNetworkLyricProviders: [LyricProvider] = [spotifyLyricProvider, lRCLyricProvider, netEaseLyricProvider]
    
    // custom order because LRCLIB is tweaking for the time being
    @ObservationIgnored lazy var allNetworkLyricProvidersForSearch: [LyricProvider] = [spotifyLyricProvider, netEaseLyricProvider, lRCLyricProvider]
    
    var isFirstFetch = true
    
    init() {
        // Set our user locale for translation language
        systemLocale = Locale.preferredLocale()
        systemLocaleString = Locale.preferredLocaleString() ?? ""
        
        #if os(macOS)
        // Generate user-saved font and load it
        let karaokeFontSize: Double = UserDefaults.standard.double(forKey: "karaokeFontSize")
        let karaokeFontName: String? = UserDefaults.standard.string(forKey: "karaokeFontName")
        if let karaokeFontName, karaokeFontSize != 0, let ourKaraokeFont = NSFont(name: karaokeFontName, size: karaokeFontSize) {
            karaokeFont = ourKaraokeFont
        } else {
            karaokeFont = NSFont.boldSystemFont(ofSize: 30)
        }
        #endif
        // Load our CoreData container for Lyrics
        coreDataContainer = NSPersistentContainer(name: "Lyrics")
        coreDataContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
            self.coreDataContainer.viewContext.mergePolicy = NSMergePolicy.overwrite
        }
        #if os(macOS)
        migrateTimestampsIfNeeded(context: coreDataContainer.viewContext)
        
        
        // Check if user must urgently update (overrides menubar)
        Task {
            mustUpdateUrgent = await updaterService.urgentUpdateExists
        }
        
        // onAppear()
        log("on appear running")
        if userDefaultStorage.latestUpdateWindowShown < 23 {
            return
        }
        #endif
        if userDefaultStorage.cookie.count == 0 {
            log("Setting hasOnboarded to false due to empty cookie")
            userDefaultStorage.hasOnboarded = false
            return
        }
        guard userDefaultStorage.hasOnboarded else {
            return
        }
        guard isPlayerRunning else {
            return
        }
        log("Application just started. lets check whats playing")
        
        isPlaying = currentPlayerInstance.isPlaying
        userDefaultStorage.hasOnboarded = currentPlayerInstance.isAuthorized
        KeyboardShortcuts.onKeyUp(for: .init("karaoke")) { [self] in
            userDefaultStorage.karaoke.toggle()
        }
        KeyboardShortcuts.onKeyUp(for: .init("lyrics")) { [self] in
            showLyrics.toggle()
        }
        KeyboardShortcuts.onKeyUp(for: .init("translate")) { [self] in
            userDefaultStorage.translate.toggle()
        }
        KeyboardShortcuts.onKeyUp(for: .init("romanize")) { [self] in
            userDefaultStorage.romanize.toggle()
        }
        KeyboardShortcuts.onKeyUp(for: .init("fullscreen")) { [self] in
            displayFullscreen.toggle()
        }
        guard userDefaultStorage.hasOnboarded else {
            return
        }
        
    }
    
    /// Iterates all configured lyric providers and returns the first successful network fetch.
    /// - Returns: Lyric payload and optional colour data sourced from the network.
    @MainActor
    func fetchAllNetworkLyrics() async -> NetworkFetchReturn {
        guard let currentlyPlaying, let currentlyPlayingName else {
            return NetworkFetchReturn(lyrics: [], colorData: nil)
        }
        for networkLyricProvider in allNetworkLyricProviders {
            do {
                log("FetchAllNetworkLyrics: fetching from \(networkLyricProvider.providerName)")
                let lyrics = try await networkLyricProvider.fetchNetworkLyrics(trackName: currentlyPlayingName, trackID: currentlyPlaying, currentlyPlayingArtist: currentlyPlayingArtist, currentAlbumName: currentAlbumName)
                if !lyrics.lyrics.isEmpty {
                    amplitude.track(eventType: "\(networkLyricProvider.providerName) Fetch")
                    log("FetchAllNetworkLyrics: returning lyrics from \(networkLyricProvider.providerName)")
                    //TODO: save lyrics here
                    SongObject(from: lyrics.lyrics, with: coreDataContainer.viewContext, trackID: currentlyPlaying, trackName: currentlyPlayingName)
                    saveCoreData()
                    return lyrics
                } else {
                    log("FetchAllNetworkLyrics: no lyrics from \(networkLyricProvider.providerName)")
                }
            } catch {
                log("Caught exception on \(networkLyricProvider.providerName): \(error)", level: .error)
            }
        }
        return NetworkFetchReturn(lyrics: [], colorData: nil)
    }
    
    #if os(macOS)
    /// Refreshes lyrics for the current track while honouring cancellation and logging failures.
    func refreshLyrics() async throws {
        // todo: romanize
        if currentPlayer == .appleMusic {
            log("Refresh Lyrics: Calling Apple Music Network fetch")
            try await appleMusicNetworkFetch()
        }
        guard let currentlyPlaying, let currentlyPlayingName, let currentDuration = currentPlayerInstance.durationAsTimeInterval else {
            return
        }
        log("Calling refresh lyrics")
        guard let finalLyrics = await self.fetch(for: currentlyPlaying, currentlyPlayingName, checkCoreDataFirst: false) else {
            log("Refresh Lyrics: Failed to run network fetch", level: .error)
            return
        }
        if finalLyrics.isEmpty {
            currentlyPlayingLyricsIndex = nil
        }
        setNewLyricsColorTranslationRomanizationAndStartUpdater(with: finalLyrics)
//        currentlyPlayingLyrics = finalLyrics
//        setBackgroundColor()
//        romanizeDidChange()
//        reloadTranslationConfigIfTranslating()
//        lyricsIsEmptyPostLoad = currentlyPlayingLyrics.isEmpty
//        log("HELLOO")
//        if isPlaying, !currentlyPlayingLyrics.isEmpty, showLyrics, userDefaultStorage.hasOnboarded {
//            startLyricUpdater()
//        }
        // we call this in self.fetch
//        callColorDataServiceOnLyricColorOrArtwork(colorData: finalLyrics.colorData)
    }
    
    /// Persists a resolved lyric colour while guarding against state changes and persistence failures.
    /// - Parameter colorData: The explicit colour from a lyric provider, if available.
    func callColorDataServiceOnLyricColorOrArtwork(colorData: Int32?) async {
        guard let currentlyPlaying else {
            colorDataLogger.log("Skipping colour persistence because no track is currently playing.")
            return
        }

        guard let backgroundColor = colorData ?? artworkImage?.findWhiteTextLegibleMostSaturatedDominantColor() else {
            colorDataLogger.log("Skipping colour persistence for track \(currentlyPlaying, privacy: .public) because no colour candidate was produced.")
            return
        }

        do {
            try await ColorDataService.saveColorToCoreData(trackID: currentlyPlaying, songColor: backgroundColor)
            colorDataLogger.info("Persisted colour \(backgroundColor, privacy: .public) for track \(currentlyPlaying, privacy: .public).")
        } catch {
            colorDataLogger.error("Failed to persist colour for track \(currentlyPlaying, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Run only on first 2.1 run. Strips whitespace from saved lyrics, and extends final timestamp to prevent karaoke mode racecondition (as well as song on loop race condition)
    func migrateTimestampsIfNeeded(context: NSManagedObjectContext) {
        if !userDefaultStorage.hasMigrated {
            let fetchRequest: NSFetchRequest<SongObject> = SongObject.fetchRequest()
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    var timestamps = object.lyricsTimestamps
                    if let lastIndex = timestamps.indices.last {
                        timestamps[lastIndex] = timestamps[lastIndex] + 5000
                        object.lyricsTimestamps = timestamps
                    }
                    var strings = object.lyricsWords
                    let indicesToRemove = strings.indices.filter { strings[$0].isEmpty }
                    strings.removeAll { $0.isEmpty }
                    for index in indicesToRemove.reversed() {
                        timestamps.remove(at: index)
                    }

                    // Update the object properties
                    object.lyricsWords = strings
                    object.lyricsTimestamps = timestamps
                }
                try context.save()
                
                // Mark migration as done
                userDefaultStorage.hasMigrated = true
            } catch {
                log("Error migrating data: \(error)", level: .error)
            }
        }
    }
    
    /// Runs once user has completed Spotify log-in. Attempt to extract cookie
    func checkIfLoggedIn() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            if let temporaryCookie = cookies.first(where: {$0.name == "sp_dc"}) {
                log("found the sp_dc cookie")
                self.userDefaultStorage.cookie = temporaryCookie.value
                NotificationCenter.default.post(name: Notification.Name("didLogIn"), object: nil)
            }
        }
    }
    
    /// Opens settings.
    func openSettings(_ openWindow: OpenWindowAction) {
        openWindow(id: "onboarding")
        NSApplication.shared.activate(ignoringOtherApps: true)
//        // send notification to check auth
//        NotificationCenter.default.post(name: Notification.Name("didClickSettings"), object: nil)
    }
    #endif
    
    /// Toggles lyrics.
    func toggleLyrics() {
        if showLyrics {
            startLyricUpdater()
        } else {
            stopLyricUpdater()
        }
    }
    
    /// Opens translation help on first run.
    func openTranslationHelpOnFirstRun(_ openURL: OpenURLAction) {
        if !userDefaultStorage.hasTranslated {
            openURL(URL(string: "https://aviwadhwa.com/TranslationHelp")!)
        }
        userDefaultStorage.hasTranslated = true
    }
    
    @MainActor
    /// Initiates a translation request and updates state based on the service result.
    /// - Parameter session: The translation session used to execute the request.
    func translationTask(_ session: TranslationSession) async {
        translationLogger.info("Starting translation for \(currentlyPlayingLyrics.count, privacy: .public) lyric lines.")
        isFetchingTranslation = true

        let request = currentlyPlayingLyrics.map { TranslationSession.Request(lyric: $0) }
        let translationResponse = await TranslationService.translationTask(session, request: request)

        switch translationResponse {
        case .success(let array):
            translationLogger.info("Translation completed successfully with \(array.count, privacy: .public) responses.")
            isFetchingTranslation = false
            guard currentlyPlayingLyrics.count == array.count else {
                translationLogger.warning("Mismatched lyric and translation counts; discarding translations.")
                translatedLyric = []
                return
            }
            translatedLyric = array.map { $0.targetText }

        case .needsConfigUpdate(let language):
            translationLogger.notice("Translation requires configuration update for language \(language.identifier, privacy: .public).")
            translationSessionConfig = TranslationSession.Configuration(source: language, target: userLocaleLanguage)
            isFetchingTranslation = false

        case .failure(let error):
            translationLogger.error("Translation failed: \(error.localizedDescription, privacy: .public)")
            isFetchingTranslation = false
        }
    }
    
    /// Regenerates romanized lyrics when the romanization preference changes.
    func romanizeDidChange() {
        romanizationTask?.cancel()

        guard userDefaultStorage.romanize else {
            romanizationLogger.info("Romanization disabled; clearing cached romanized lyrics.")
            romanizedLyrics = []
            return
        }

        romanizationLogger.info("Regenerating romanized lyrics for track \(currentlyPlaying ?? "unknown", privacy: .public).")

        let sourceLyrics: [LyricLine]
        if !chineseConversionLyrics.isEmpty {
            sourceLyrics = chineseConversionLyrics.enumerated().map { index, words in
                let baseTime = currentlyPlayingLyrics.indices.contains(index) ? currentlyPlayingLyrics[index].startTimeMS : 0
                return LyricLine(startTime: baseTime, words: words)
            }
        } else {
            sourceLyrics = currentlyPlayingLyrics
        }

        romanizationTask = Task { [weak self] in
            guard let self else { return }
            do {
                var results: [String] = []
                for lyric in sourceLyrics {
                    try Task.checkCancellation()
                    do {
                        let romanized = try await RomanizerService.generateRomanizedLyric(lyric)
                        results.append(romanized)
                    } catch RomanizerServiceError.emptyInput {
                        continue
                    }
                }

                await MainActor.run {
                    self.romanizedLyrics = results
                }
                romanizationLogger.info("Romanized \(results.count, privacy: .public) lyric lines.")
            } catch is CancellationError {
                romanizationLogger.notice("Romanization task cancelled for track \(self.currentlyPlaying ?? "unknown", privacy: .public).")
            } catch {
                romanizationLogger.error("Romanization task failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.romanizedLyrics = []
                }
            }
        }
    }
    
/// Only called when Romanize is true
//    func romanizeMetadata() {
//        // Generate romanized metadata from name & artist
//        if userDefaultStorage.romanizeMetadata, let currentlyPlayingName, let romanizedName = RomanizerService.generateRomanizedString(currentlyPlayingName), let currentlyPlayingArtist, let romanizedArtist = RomanizerService.generateRomanizedString(currentlyPlayingArtist) {
//            self.currentlyPlayingName = romanizedName
//            self.currentlyPlayingArtist = romanizedArtist
//        }
//    }
    
    /// Romanizes the currently playing track name.
    /// - Parameter currentlyPlayingName: The track name to romanize.
    /// - Returns: A romanized representation if conversion succeeds.
    func romanizeName(_ currentlyPlayingName: String) async -> String? {
        do {
            return try await RomanizerService.generateRomanizedString(currentlyPlayingName)
        } catch {
            romanizationLogger.error("Failed to romanize name: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Romanizes the currently playing artist name.
    /// - Parameter currentlyPlayingArtist: The artist name to romanize.
    /// - Returns: A romanized representation if conversion succeeds.
    func romanizeArtist(_ currentlyPlayingArtist: String) async -> String? {
        do {
            return try await RomanizerService.generateRomanizedString(currentlyPlayingArtist)
        } catch {
            romanizationLogger.error("Failed to romanize artist: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// Regenerates Chinese script conversions when the preference changes.
    func chinesePreferenceDidChange() {
        chineseConversionTask?.cancel()

        guard let chinesePreference = ChineseConversion(rawValue: userDefaultStorage.chinesePreference), chinesePreference != .none else {
            chineseConversionLogger.info("Clearing Chinese conversion lyrics because preference is set to none.")
            chineseConversionLyrics = []
            romanizeDidChange()
            return
        }

        chineseConversionLogger.info("Generating Chinese conversion for track \(currentlyPlaying ?? "unknown", privacy: .public) using style \(chinesePreference.description, privacy: .public).")
        let lyrics = currentlyPlayingLyrics

        chineseConversionTask = Task { [weak self] in
            guard let self else { return }
            do {
                var converted: [String] = []
                for lyric in lyrics {
                    try Task.checkCancellation()
                    do {
                        let value: String
                        switch chinesePreference {
                        case .none:
                            continue
                        case .simplified:
                            value = try await RomanizerService.generateMainlandTransliteration(lyric)
                        case .traditionalNeutral:
                            value = try await RomanizerService.generateTraditionalNeutralTransliteration(lyric)
                        case .traditionalTaiwan:
                            value = try await RomanizerService.generateTaiwanTransliteration(lyric)
                        case .traditionalHK:
                            value = try await RomanizerService.generateHongKongTransliteration(lyric)
                        }
                        converted.append(value)
                    } catch RomanizerServiceError.emptyInput {
                        continue
                    }
                }

                await MainActor.run {
                    self.chineseConversionLyrics = converted
                    self.romanizeDidChange()
                }
                chineseConversionLogger.info("Generated \(converted.count, privacy: .public) converted lyric lines.")
            } catch is CancellationError {
                chineseConversionLogger.notice("Chinese conversion task cancelled for track \(self.currentlyPlaying ?? "unknown", privacy: .public).");
            } catch {
                chineseConversionLogger.error("Chinese conversion task failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.chineseConversionLyrics = []
                    self.romanizeDidChange()
                }
            }
        }
    }
    
    #if os(macOS)
    /// Saves karaoke font on termination.
    func saveKaraokeFontOnTermination() {
        // This code will be executed just before the app terminates
     UserDefaults.standard.set(karaokeFont.fontName, forKey: "karaokeFontName")
     UserDefaults.standard.set(Double(karaokeFont.pointSize), forKey: "karaokeFontSize")
    }
    
    /// Handles playback change notifications published by the Music app.
    func appleMusicPlaybackDidChange(_ notification: Notification) {
        guard currentPlayer == .appleMusic else {
            return
        }
        if notification.userInfo?["Player State"] as? String == "Playing" {
            log("is playing")
            isPlaying = true
        } else {
            log("paused. timer canceled")
            isPlaying = false
            // manually cancels the lyric-updater task bc media is paused
        }
        let currentlyPlayingName = (notification.userInfo?["Name"] as? String)
        guard let currentlyPlayingName else {
            self.currentlyPlayingName = nil
            currentlyPlayingArtist = nil
            currentAlbumName = nil
            return
        }
        if currentlyPlayingName == "" {
            self.currentlyPlayingName = nil
            currentlyPlayingArtist = nil
            currentAlbumName = nil
        } else {
            self.currentlyPlayingName = currentlyPlayingName
            currentlyPlayingArtist = (notification.userInfo?["Artist"] as? String)
            currentAlbumName = (notification.userInfo?["Album"] as? String)
            if let duration = currentPlayerInstance.duration {
                self.duration = duration
            }
            log("REOPEN: currentlyPlayingName is \(currentlyPlayingName)")
            currentlyPlayingAppleMusicPersistentID = appleMusicPlayer.persistentID
        }
    }
    
    /// Responds to Spotify Connect state changes so the UI stays in sync.
    func spotifyPlaybackDidChange(_ notification: Notification) {
        guard currentPlayer == .spotify else {
            return
        }
        if notification.userInfo?["Player State"] as? String == "Playing" {
            log("is playing")
            isPlaying = true
        } else {
            log("paused. timer canceled")
            isPlaying = false
            // manually cancels the lyric-updater task bc media is paused
        }
        log(notification.userInfo?["Track ID"] as? String)
        let currentlyPlaying = (notification.userInfo?["Track ID"] as? String)?.spotifyProcessedUrl()
        let currentlyPlayingName = (notification.userInfo?["Name"] as? String)
        if currentlyPlaying != "", currentlyPlayingName != "", let duration = currentPlayerInstance.duration {
            self.currentlyPlaying = currentlyPlaying
            self.currentlyPlayingName = currentlyPlayingName
            self.currentlyPlayingArtist = spotifyPlayer.artistName
            self.currentAlbumName = spotifyPlayer.albumName
            self.duration = duration
        }
    }
    
    /// Sets up observers and state when the main UI hierarchy appears.
    func onAppear(_ openWindow: OpenWindowAction) {
        setCurrentProperties()
    }
    
    /// Refreshes lyrics and metadata when the playing track identifier changes.
    func onCurrentlyPlayingIDChange() async {
        currentlyPlayingLyricsIndex = nil
        currentlyPlayingLyrics = []
        translatedLyric = []
        romanizedLyrics = []
        chineseConversionLyrics = []
        
        if userDefaultStorage.hasOnboarded, let currentlyPlaying = currentlyPlaying, let currentlyPlayingName = currentlyPlayingName, let lyrics = await fetch(for: currentlyPlaying, currentlyPlayingName) {
            setNewLyricsColorTranslationRomanizationAndStartUpdater(with: lyrics)
//            currentlyPlayingLyrics = lyrics
//            setBackgroundColor()
//            romanizeDidChange()
//            reloadTranslationConfigIfTranslating()
//            lyricsIsEmptyPostLoad = lyrics.isEmpty
//            if isPlaying, !currentlyPlayingLyrics.isEmpty, showLyrics, userDefaultStorage.hasOnboarded {
//                log("STARTING UPDATER")
//                startLyricUpdater()
//            }
        }
    }
    
    /// Sets current properties.
    private func setCurrentProperties() {
        switch currentPlayer {
            case .appleMusic:
                if let currentTrackName = appleMusicPlayer.trackName, let currentArtistName = appleMusicPlayer.artistName, let duration = appleMusicPlayer.duration, let currentAlbumName = appleMusicPlayer.albumName {
                    // Don't set currentlyPlaying here: the persistentID change triggers the appleMusicFetch which will set spotify's currentlyPlaying
                    if currentTrackName == "" {
                        currentlyPlayingName = nil
                        currentlyPlayingArtist = nil
                        self.currentAlbumName = nil
                    } else {
                        currentlyPlayingName = currentTrackName
                        currentlyPlayingArtist = currentArtistName
                        self.duration = duration
                        self.currentAlbumName = currentAlbumName
                    }
                    log("ON APPEAR HAS UPDATED APPLE MUSIC SONG ID")
                    currentlyPlayingAppleMusicPersistentID = appleMusicPlayer.persistentID
                }
            case .spotify:
                if let currentTrack = spotifyPlayer.trackID, let currentTrackName = spotifyPlayer.trackName, let currentArtistName =  spotifyPlayer.artistName, currentTrack != "", currentTrackName != "", let duration = spotifyPlayer.duration, let currentAlbumName = spotifyPlayer.albumName {
                    currentlyPlaying = currentTrack
                    currentlyPlayingName = currentTrackName
                    currentlyPlayingArtist = currentArtistName
                    self.duration = duration
                    self.currentAlbumName = currentAlbumName
                    self.currentTime = CurrentTimeWithStoredDate(currentTime: 0)
                    log(currentTrack)
                }
        }
    }
    
    #else
    /// Sets current properties.
    func setCurrentProperties() {
        currentlyPlaying = spotifyPlayer.currentTrack?.uri?.spotifyProcessedUrl()
        currentlyPlayingName = spotifyPlayer.trackName
        currentlyPlayingArtist = spotifyPlayer.artistName
    }
    #endif

    /// Calculates the lyric index that should be highlighted for a timestamp.
    func upcomingIndex(_ currentTime: Double) -> Int? {
        if let currentlyPlayingLyricsIndex {
            let newIndex = currentlyPlayingLyricsIndex + 1
            if newIndex >= currentlyPlayingLyrics.count {
                log("REACHED LAST LYRIC!!!!!!!!")
                // if current time is before our current index's start time, the user has scrubbed and rewinded
                // reset into linear search mode
                if currentTime < currentlyPlayingLyrics[currentlyPlayingLyricsIndex].startTimeMS {
                    return currentlyPlayingLyrics.firstIndex(where: {$0.startTimeMS > currentTime})
                }
                // we've reached the end of the song, we're past the last lyric
                //TODO: remove these
                #if os(macOS)
                currentlyPlayingAppleMusicPersistentID = nil
                #endif
                currentlyPlaying = nil
                return nil
            }
            else if  currentTime > currentlyPlayingLyrics[currentlyPlayingLyricsIndex].startTimeMS, currentTime < currentlyPlayingLyrics[newIndex].startTimeMS {
                log("just the next lyric")
                return newIndex
            }
        }
        // linear search through the array to find the first lyric that's right after the current time
        // done on first lyric update for the song, as well as post-scrubbing
        return currentlyPlayingLyrics.firstIndex(where: {$0.startTimeMS > currentTime})
    }
    
    /// Periodically polls the active lyric provider to stay aligned with playback.
    func lyricUpdater() async throws {
        repeat {
            guard let currentTime = currentPlayerInstance.currentTime, let lastIndex: Int = upcomingIndex(currentTime) else {
                stopLyricUpdater()
                return
            }
            // If there is no current index (perhaps lyric updater started late and we're mid-way of the first lyric, or the user scrubbed and our index is expired)
            // Then we set the current index to the one before our anticipated index
            if currentlyPlayingLyricsIndex == nil && lastIndex > 0 {
                currentlyPlayingLyricsIndex = lastIndex-1
            }
            let nextTimestamp = currentlyPlayingLyrics[lastIndex].startTimeMS
            let diff = nextTimestamp - currentTime
            log("current time: \(currentTime)")
            self.currentTime = CurrentTimeWithStoredDate(currentTime: currentTime)
            log("next time: \(nextTimestamp)")
            log("the difference is \(diff)")
            try await Task.sleep(nanoseconds: UInt64(1000000*diff))
            log("lyrics exist: \(!currentlyPlayingLyrics.isEmpty)")
            log("last index: \(lastIndex)")
            log("currently playing lryics index: \(currentlyPlayingLyricsIndex)")
            if currentlyPlayingLyrics.count > lastIndex {
                currentlyPlayingLyricsIndex = lastIndex
            } else {
                currentlyPlayingLyricsIndex = nil
                
            }
            log(currentlyPlayingLyricsIndex ?? "nil")
        } while !Task.isCancelled
    }
    
    /// Starts lyric updater.
    func startLyricUpdater() {
        currentLyricsUpdaterTask?.cancel()
        if !isPlaying || currentlyPlayingLyrics.isEmpty || mustUpdateUrgent {
            return
        }
        // If an index exists, we're unpausing: meaning we must instantly find the current lyric
        if currentlyPlayingLyricsIndex != nil {
            guard let currentTime = currentPlayerInstance.currentTime, let lastIndex: Int = upcomingIndex(currentTime) else {
                stopLyricUpdater()
                return
            }
            // If there is no current index (perhaps lyric updater started late and we're mid-way of the first lyric, or the user scrubbed and our index is expired)
            // Then we set the current index to the one before our anticipated index
            if lastIndex > 0 {
                currentlyPlayingLyricsIndex = lastIndex-1
            }
        } else {
            #if os(macOS)
            if currentPlayer == .spotify {
                currentLyricsDriftFix?.cancel()
                currentLyricsDriftFix =             // Only run drift fix for new songs
                Task {
                    try await spotifyPlayer.fixSpotifyLyricDrift()
                }
                Task {
                    try await currentLyricsDriftFix?.value
                }
            }
            #endif
        }
        currentLyricsUpdaterTask = Task {
            do {
                try await lyricUpdater()
            } catch {
                log("lyrics were canceled \(error)", level: .error)
            }
        }
        Task {
            try await currentLyricsUpdaterTask?.value
        }
        
    }
    
    /// Stops lyric updater.
    func stopLyricUpdater() {
        log("stop called")
        currentLyricsUpdaterTask?.cancel()
    }
    
    /// Persists pending Core Data changes when the view-context has dirty state.
    func saveCoreData() {
        let context = coreDataContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                log("Saved CoreData!")
            } catch {
                log("core data error \(error)", level: .error)
                // Show some error here
            }
        } else {
            log("BAD COREDATA CALL!!")
        }
    }
    
    /// Retrieves lyrics for the supplied track, optionally preferring cached Core Data results.
    func fetch(for trackID: String, _ trackName: String, checkCoreDataFirst: Bool = true) async -> [LyricLine]? {
        if isFirstFetch {
            isFirstFetch = false
        }
        log("Fetch Called for trackID \(trackID), trackName \(trackName), checkCoreDataFirst: \(checkCoreDataFirst)")
        currentFetchTask?.cancel()
        // i don't set isFetching to true here to prevent "flashes" for CoreData fetches
        defer {
            isFetching = false
        }
        currentFetchTask = Task { try await self.fetchLyrics(for: trackID, trackName, checkCoreDataFirst: checkCoreDataFirst) }
        do {
            return try await currentFetchTask?.value
        } catch {
            log("error \(error)", level: .error)
            return nil
        }
    }

    #if os(macOS)
    /// Converts the stored integer colour value into a SwiftUI ``Color``.
    func intToRGB(_ value: Int32) -> Color {
        // Convert negative numbers to an unsigned 32-bit representation
        let unsignedValue = UInt32(bitPattern: value)
        
        // Extract RGB components
        let red = Double((unsignedValue >> 16) & 0xFF)
        let green = Double((unsignedValue >> 8) & 0xFF)
        let blue = Double(unsignedValue & 0xFF)
        return Color(red: red/255, green: green/255, blue: blue/255) //(red, green, blue)
    }
    
    /// Applies the current song background colour from Core Data or artwork analysis.
    func setBackgroundColor() {
        guard let currentlyPlaying else {
            return
        }
        let fetchRequest: NSFetchRequest<IDToColor> = IDToColor.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", currentlyPlaying) // Replace trackID with the desired value

        do {
            let results = try coreDataContainer.viewContext.fetch(fetchRequest)
            if let idToColor = results.first {
                self.currentBackground = intToRGB(idToColor.songColor)
            } else {
                self.currentBackground = nil
            }
        } catch {
            log("Error fetching SongObject:", error, level: .error)
        }
    }
    #endif
    
    /// Pulls lyrics from Core Data when possible and falls back to network providers.
    func fetchLyrics(for trackID: String, _ trackName: String, checkCoreDataFirst: Bool) async throws -> [LyricLine] {
        let initiatingTrackID = trackID
        
        if checkCoreDataFirst, let lyrics = fetchFromCoreData(for: trackID) {
            log("ViewModel FetchLyrics: got lyrics from core data :D \(trackID) \(trackName)")
            try Task.checkCancellation()
            amplitude.track(eventType: "CoreData Fetch")
            // verify non-stale trackID
            if initiatingTrackID != self.currentlyPlaying {
                log("FetchLyrics: CoreData result stale (initiated: \(initiatingTrackID), current: \(self.currentlyPlaying ?? "nil")). Throwing.")
                throw FetchError.staleTrack
            }
            return lyrics
        } else {
            log("ViewModel FetchLyrics: no lyrics from core data, going to download from internet \(trackID) \(trackName)")
            log("ViewModel FetchLyrics: isFetching set to true")
            isFetching = true
            
            var networkLyrics: NetworkFetchReturn = await fetchAllNetworkLyrics()
            
            // verify non-stale trackID
            if initiatingTrackID != self.currentlyPlaying {
                log("FetchLyrics: Network result stale (initiated: \(initiatingTrackID), current: \(self.currentlyPlaying ?? "nil")). Throwing.")
                throw FetchError.staleTrack
            }
            
            guard let duration = currentPlayerInstance.duration else {
                log("FetchLyrics: Couldn't access current player duration. Giving up on netwokr fetch")
                return []
            }
            networkLyrics = networkLyrics.processed(withSongName: trackName, duration: duration)
            
            // verify non-stale trackID
            if initiatingTrackID == self.currentlyPlaying {
                await callColorDataServiceOnLyricColorOrArtwork(colorData: networkLyrics.colorData)
            } else {
                log("FetchLyrics: Skipping color save due to stale track (initiated: \(initiatingTrackID), current: \(self.currentlyPlaying ?? "nil")).")
                throw FetchError.staleTrack
            }
            return networkLyrics.lyrics
        }
    }

    /// Deletes lyric.
    func deleteLyric(trackID: String) {
        do {
            let fetchRequest: NSFetchRequest<SongObject> = SongObject.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", trackID)
            let object = try coreDataContainer.viewContext.fetch(fetchRequest).first
            object?.lyricsTimestamps.removeAll()
            object?.lyricsWords.removeAll()
            try coreDataContainer.viewContext.save()
            currentlyPlayingLyricsIndex = nil
            currentlyPlayingLyrics = []
            translatedLyric = []
            romanizedLyrics = []
            chineseConversionLyrics = []
            lyricsIsEmptyPostLoad = true
        } catch {
            log("Error deleting data: \(error)", level: .error)
        }
    }
    
    /// Fetches from core data.
    func fetchFromCoreData(for trackID: String) -> [LyricLine]? {
        let fetchRequest: NSFetchRequest<SongObject> = SongObject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", trackID) // Replace trackID with the desired value

        do {
            let results = try coreDataContainer.viewContext.fetch(fetchRequest)
            if let songObject = results.first {
                // Found the SongObject with the matching trackID
                let lyricsArray = zip(songObject.lyricsTimestamps, songObject.lyricsWords).map { LyricLine(startTime: $0, words: $1) }
                log("Found SongObject with ID:", songObject.id)
                return lyricsArray
            } else {
                // No SongObject found with the given trackID
                log("No SongObject found with the provided trackID. \(trackID)")
            }
        } catch {
            log("Error fetching SongObject:", error, level: .error)
        }
        return nil
    }
    
    #if os(macOS)
    /// Rebuilds the translation session if the user changes related preferences mid-request.
    func reloadTranslationConfigIfTranslating() -> Bool {
        if userDefaultStorage.translate {
            if translationSessionConfig == TranslationSession.Configuration(source: translationSourceLanguage, target: userLocaleLanguage) {
                translationSessionConfig?.invalidate()
            } else {
                translationSessionConfig = TranslationSession.Configuration(source: translationSourceLanguage, target: userLocaleLanguage)
            }
            return true
        } else {
            return false
        }
    }
    #endif
    
    /// Fetches translation source language.
    func fetchTranslationSourceLanguage() {
        guard let currentlyPlaying else {
            log("Translation: ignoring translationSourceLang fetch due to nil currentlyPlaying")
            return
        }
        let fetchRequest: NSFetchRequest<SongToLocale> = SongToLocale.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", currentlyPlaying) // Replace trackID with the desired value

        do {
            let results = try coreDataContainer.viewContext.fetch(fetchRequest)
            if let songToLocale = results.first?.locale {
                self.translationSourceLanguage = Locale.Language(identifier: songToLocale)
            } else {
                self.translationSourceLanguage = nil
            }
        } catch {
            log("Error fetching translationSourceLanguage:", error, level: .error)
        }
    }
    
    #if os(macOS)
    /// Sets new lyrics color translation romanization and start updater.
    func setNewLyricsColorTranslationRomanizationAndStartUpdater(with newLyrics: [LyricLine]) {
        currentlyPlayingLyrics = newLyrics
        setBackgroundColor()
        fetchTranslationSourceLanguage()
        reloadTranslationConfigIfTranslating()
//        romanizeDidChange()
        chinesePreferenceDidChange()
        // we romanize afterwards, in-case the chinese conversion array was populated
        romanizeDidChange()
        lyricsIsEmptyPostLoad = currentlyPlayingLyrics.isEmpty
        if isPlaying, !currentlyPlayingLyrics.isEmpty, showLyrics, userDefaultStorage.hasOnboarded {
            startLyricUpdater()
        }
    }
    
    @MainActor
    /// Uploads local lrc file.
    func uploadLocalLRCFile() async throws {
        guard let currentlyPlaying = currentlyPlaying, let currentlyPlayingName = currentlyPlayingName else {
            throw CancellationError()
        }
        let duration = self.duration
        let localLyrics = try await localFileUploadProvider.localFetch(for: currentlyPlaying, currentlyPlayingName)
        let cleanLyrics = NetworkFetchReturn(lyrics: localLyrics, colorData: nil).processed(withSongName: currentlyPlayingName, duration: duration).lyrics
        if self.currentlyPlaying == currentlyPlaying {
            setNewLyricsColorTranslationRomanizationAndStartUpdater(with: cleanLyrics)
        }
        
        SongObject(from: cleanLyrics, with: coreDataContainer.viewContext, trackID: currentlyPlaying, trackName: currentlyPlayingName)
        saveCoreData()
    }
    #endif
    
    /// Completes the remaining onboarding actions after the settings lyric step finishes.
    func stepsToTakeAfterSettingsLyrics() async {
        
    }
    
    /// Marks onboarding as complete and updates analytics state.
    func didOnboard() {
        guard isPlayerRunning else {
            isPlaying = false
            currentlyPlaying = nil
            currentlyPlayingName = nil
            currentlyPlayingArtist = nil
            #if os(macOS)
            currentlyPlayingAppleMusicPersistentID = nil
            #endif
            return
        }
        log("Application just started (finished onboarding). lets check whats playing")
        if currentPlayerInstance.isPlaying {
            isPlaying = true
        }
        setCurrentProperties()
        startLyricUpdater()
    }
    #if os(macOS)
    /// Resets karaoke prefs.
    func resetKaraokePrefs() {
        userDefaultStorage.karaokeModeHoveringSetting = false
        userDefaultStorage.karaokeUseAlbumColor = true
        userDefaultStorage.karaokeShowMultilingual = true
        userDefaultStorage.karaokeTransparency = 50
        karaokeFont = NSFont.boldSystemFont(ofSize: 30)
        colorBinding.wrappedValue = Color(.sRGB, red: 0.98, green: 0.0, blue: 0.98)
    }
    #endif
}

#if os(macOS)
// Apple Music Code
extension ViewModel {
    /// Similar structure to my other Async functions. Only 1 appleMusic) can run at any given moment
    func appleMusicStarter() async {
        log("apple music test called again, cancelling previous")
        currentAppleMusicFetchTask?.cancel()
        let newFetchTask = Task {
            try await self.appleMusicFetch()
        }
        currentAppleMusicFetchTask = newFetchTask
        do {
            return try await newFetchTask.value
        } catch {
            log("error \(error)", level: .error)
            return
        }
    }
    
    /// Polls the Music app for the latest playback state and metadata.
    func appleMusicFetch() async throws {
        // check coredata for apple music persistent id -> spotify id mapping
        if let coreDataSpotifyID = fetchSpotifyIDFromPersistentIDCoreData() {
            if !Task.isCancelled {
                log("Apple Music CoreData Fetch: setting currentlyPlaying to \(coreDataSpotifyID)")
                self.currentlyPlaying = coreDataSpotifyID
                return
            }
        }
        log("Apple Music Fetch: No CoreData val. Fetching from network")
        try await appleMusicNetworkFetch()
    }
    
    /// Resolves additional Apple Music metadata via the web API when needed.
    func appleMusicNetworkFetch() async throws {
        isFetching = true
//        do {
//            log("Apple Music Network Fetch: 3 second sleep")
//            try await Task.sleep(for: .seconds(3))
//        } catch {
//            log("Apple Music Network Fetch cancelled during the 3 seconds of sleep")
//        }
        log("Apple Music Network Fetch: isFetching set to true")
        // coredata didn't get us anything
//        try await spotifyLyricProvider.generateAccessToken()
        
        // Task cancelled means we're working with old song data, so dont update Spotify ID with old song's ID
        
        // search for equivalent spotify song
        if let spotifyResult = try await musicToSpotifyHelper() {
            self.currentlyPlayingName = spotifyResult.SpotifyName
            self.currentlyPlayingArtist = spotifyResult.SpotifyArtist
            self.currentAlbumName = spotifyResult.SpotifyAlbum
            self.currentlyPlaying = spotifyResult.SpotifyID
        } else {
            if let alternativeID = appleMusicPlayer.alternativeID, alternativeID != "" {
                try Task.checkCancellation()
                self.currentlyPlaying = alternativeID
            } else {
                lyricsIsEmptyPostLoad = true
            }
        }
        
        
        if let currentlyPlayingAppleMusicPersistentID, let currentlyPlaying {
            log("Apple Music Network Fetch: Saving persistent id \(currentlyPlayingAppleMusicPersistentID) and spotify ID \(currentlyPlaying)")
            // save the mapping into coredata persistentIDToSpotify
            let newPersistentIDToSpotifyIDMapping = PersistentIDToSpotify(context: coreDataContainer.viewContext)
            newPersistentIDToSpotifyIDMapping.persistentID = currentlyPlayingAppleMusicPersistentID
            newPersistentIDToSpotifyIDMapping.spotifyID = currentlyPlaying
            saveCoreData()
        }
    }
    
    /// Fetches spotify id from persistent id core data.
    func fetchSpotifyIDFromPersistentIDCoreData() -> String? {
        let fetchRequest: NSFetchRequest<PersistentIDToSpotify> = PersistentIDToSpotify.fetchRequest()
        guard let currentlyPlayingAppleMusicPersistentID else {
            log("No persistent ID available. it's nil! should have never happened")
            return nil
        }
        fetchRequest.predicate = NSPredicate(format: "persistentID == %@", currentlyPlayingAppleMusicPersistentID) // Replace persistentID with the desired value

        do {
            let results = try coreDataContainer.viewContext.fetch(fetchRequest)
            if let persistentIDToSpotify = results.first {
                // Found the persistentIDToSpotify object with the matching persistentID
                log("Apple Music CoreData Fetch: Found SpotifyID \(persistentIDToSpotify.spotifyID) for \(persistentIDToSpotify.persistentID)")
                return persistentIDToSpotify.spotifyID
            } else {
                // No SongObject found with the given trackID
                log("No spotifyID found with the provided persistentID. \(currentlyPlayingAppleMusicPersistentID)")
            }
        } catch {
            log("Error fetching persistentIDToSpotify:", error, level: .error)
        }
        return nil
    }
    
    /// Creates a helper that maps Apple Music identifiers to Spotify equivalents.
    private func musicToSpotifyHelper() async throws -> AppleMusicHelper? {
        // Manually search song name, artist name
        guard let currentlyPlayingArtist, let currentlyPlayingName else {
            log("\(#function) currentlyPlayingName or currentlyPlayingArtist missing")
            return nil
        }
        return try await spotifyLyricProvider.searchForTrackForAppleMusic(artist: currentlyPlayingArtist, track: currentlyPlayingName)
    }
}
#endif

