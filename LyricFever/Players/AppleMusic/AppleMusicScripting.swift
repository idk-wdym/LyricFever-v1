//
//  AppleMusicScripting.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 05/04/24.
// Taken from Jukebox https://github.com/Jaysce/Jukebox/blob/main/Jukebox/ScriptingBridge/MusicApplication.swift


import AppKit
import ScriptingBridge

// MARK: MusicEKnd
@objc public enum MusicEKnd : AEKeyword {
    case trackListing = 0x6b54726b /* b'kTrk' */
    case albumListing = 0x6b416c62 /* b'kAlb' */
    case cdInsert = 0x6b434469 /* b'kCDi' */
}

// MARK: MusicEnum
@objc public enum MusicEnum : AEKeyword {
    case standard = 0x6c777374 /* b'lwst' */
    case detailed = 0x6c776474 /* b'lwdt' */
}

// MARK: MusicEPlS
@objc public enum MusicEPlS : AEKeyword {
    case stopped = 0x6b505353 /* b'kPSS' */
    case playing = 0x6b505350 /* b'kPSP' */
    case paused = 0x6b505370 /* b'kPSp' */
    case fastForwarding = 0x6b505346 /* b'kPSF' */
    case rewinding = 0x6b505352 /* b'kPSR' */
}

// MARK: MusicERpt
@objc public enum MusicERpt : AEKeyword {
    case off = 0x6b52704f /* b'kRpO' */
    case one = 0x6b527031 /* b'kRp1' */
    case all = 0x6b416c6c /* b'kAll' */
}

// MARK: MusicEShM
@objc public enum MusicEShM : AEKeyword {
    case songs = 0x6b536853 /* b'kShS' */
    case albums = 0x6b536841 /* b'kShA' */
    case groupings = 0x6b536847 /* b'kShG' */
}

// MARK: MusicESrc
@objc public enum MusicESrc : AEKeyword {
    case library = 0x6b4c6962 /* b'kLib' */
    case audioCD = 0x6b414344 /* b'kACD' */
    case mp3CD = 0x6b4d4344 /* b'kMCD' */
    case radioTuner = 0x6b54756e /* b'kTun' */
    case sharedLibrary = 0x6b536864 /* b'kShd' */
    case iTunesStore = 0x6b495453 /* b'kITS' */
    case unknown = 0x6b556e6b /* b'kUnk' */
}

// MARK: MusicESrA
@objc public enum MusicESrA : AEKeyword {
    case albums = 0x6b53724c /* b'kSrL' */
    case all = 0x6b416c6c /* b'kAll' */
    case artists = 0x6b537252 /* b'kSrR' */
    case composers = 0x6b537243 /* b'kSrC' */
    case displayed = 0x6b537256 /* b'kSrV' */
    case names = 0x6b537253 /* b'kSrS' */
}

// MARK: MusicESpK
@objc public enum MusicESpK : AEKeyword {
    case none = 0x6b4e6f6e /* b'kNon' */
    case folder = 0x6b537046 /* b'kSpF' */
    case genius = 0x6b537047 /* b'kSpG' */
    case library = 0x6b53704c /* b'kSpL' */
    case music = 0x6b53705a /* b'kSpZ' */
    case purchasedMusic = 0x6b53704d /* b'kSpM' */
}

// MARK: MusicEMdK
@objc public enum MusicEMdK : AEKeyword {
    case song = 0x6b4d6453 /* b'kMdS' */
    case musicVideo = 0x6b566456 /* b'kVdV' */
    case unknown = 0x6b556e6b /* b'kUnk' */
}

// MARK: MusicERtK
@objc public enum MusicERtK : AEKeyword {
    case user = 0x6b527455 /* b'kRtU' */
    case computed = 0x6b527443 /* b'kRtC' */
}

// MARK: MusicEAPD
@objc public enum MusicEAPD : AEKeyword {
    case computer = 0x6b415043 /* b'kAPC' */
    case airPortExpress = 0x6b415058 /* b'kAPX' */
    case appleTV = 0x6b415054 /* b'kAPT' */
    case airPlayDevice = 0x6b41504f /* b'kAPO' */
    case bluetoothDevice = 0x6b415042 /* b'kAPB' */
    case homePod = 0x6b415048 /* b'kAPH' */
    case unknown = 0x6b415055 /* b'kAPU' */
}

// MARK: MusicEClS
@objc public enum MusicEClS : AEKeyword {
    case unknown = 0x6b556e6b /* b'kUnk' */
    case purchased = 0x6b507572 /* b'kPur' */
    case matched = 0x6b4d6174 /* b'kMat' */
    case uploaded = 0x6b55706c /* b'kUpl' */
    case ineligible = 0x6b52656a /* b'kRej' */
    case removed = 0x6b52656d /* b'kRem' */
    case error = 0x6b457272 /* b'kErr' */
    case duplicate = 0x6b447570 /* b'kDup' */
    case subscription = 0x6b537562 /* b'kSub' */
    case noLongerAvailable = 0x6b526576 /* b'kRev' */
    case notUploaded = 0x6b557050 /* b'kUpP' */
}

// MARK: MusicGenericMethods
@objc public protocol MusicGenericMethods {
    /// Print the specified object(s)
    @objc optional func printPrintDialog(_ printDialog: Bool, withProperties: [AnyHashable : Any]!, kind: MusicEKnd, theme: String!)
    /// Close an object
    @objc optional func close()
    /// Delete an element from an object
    @objc optional func delete()
    /// Duplicate one or more object(s)
    @objc optional func duplicateTo(_ to: SBObject!) -> SBObject
    /// Verify if an object exists
    @objc optional func exists() -> Bool
    /// Open the specified object(s)
    @objc optional func `open`()
    /// Save the specified object(s)
    @objc optional func save()
    /// play the current track or the specified track or file.
    @objc optional func playOnce(_ once: Bool)
    /// select the specified object(s)
    @objc optional func select()
}

// MARK: MusicApplication
@objc public protocol MusicApplication: SBApplicationProtocol {
    /// Returns the Music app Air Play Devices collection.
    @objc optional func AirPlayDevices() -> SBElementArray
    /// Returns the Music app browser Windows collection.
    @objc optional func browserWindows() -> SBElementArray
    /// Returns the Music app encoders collection.
    @objc optional func encoders() -> SBElementArray
    /// Returns the Music app EQ Presets collection.
    @objc optional func EQPresets() -> SBElementArray
    /// Returns the Music app EQ Windows collection.
    @objc optional func EQWindows() -> SBElementArray
    /// Returns the Music app miniplayer Windows collection.
    @objc optional func miniplayerWindows() -> SBElementArray
    /// Returns the Music app playlists collection.
    @objc optional func playlists() -> SBElementArray
    /// Returns the Music app playlist Windows collection.
    @objc optional func playlistWindows() -> SBElementArray
    /// Returns the Music app sources collection.
    @objc optional func sources() -> SBElementArray
    /// Returns the Music app tracks collection.
    @objc optional func tracks() -> SBElementArray
    /// Returns the Music app video Windows collection.
    @objc optional func videoWindows() -> SBElementArray
    /// Returns the Music app visuals collection.
    @objc optional func visuals() -> SBElementArray
    /// Returns the Music app windows collection.
    @objc optional func windows() -> SBElementArray
    @objc optional var AirPlayEnabled: Bool { get } // is AirPlay currently enabled?
    @objc optional var converting: Bool { get } // is a track currently being converted?
    @objc optional var currentAirPlayDevices: [MusicAirPlayDevice] { get } // the currently selected AirPlay device(s)
    @objc optional var currentEncoder: MusicEncoder { get } // the currently selected encoder (MP3, AIFF, WAV, etc.)
    @objc optional var currentEQPreset: MusicEQPreset { get } // the currently selected equalizer preset
    @objc optional var currentPlaylist: MusicPlaylist { get } // the playlist containing the currently targeted track
    @objc optional var currentStreamTitle: String { get } // the name of the current track in the playing stream (provided by streaming server)
    @objc optional var currentStreamURL: String { get } // the URL of the playing stream or streaming web site (provided by streaming server)
    @objc optional var currentTrack: MusicTrack { get } // the current targeted track
    @objc optional var currentVisual: MusicVisual { get } // the currently selected visual plug-in
    @objc optional var EQEnabled: Bool { get } // is the equalizer enabled?
    @objc optional var fixedIndexing: Bool { get } // true if all AppleScript track indices should be independent of the play order of the owning playlist.
    @objc optional var frontmost: Bool { get } // is this the active application?
    @objc optional var fullScreen: Bool { get } // is the application using the entire screen?
    @objc optional var name: String { get } // the name of the application
    @objc optional var mute: Bool { get } // has the sound output been muted?
    @objc optional var playerPosition: Double { get } // the player’s position within the currently playing track in seconds.
    @objc optional var playerState: MusicEPlS { get } // is the player stopped, paused, or playing?
    @objc optional var selection: SBObject { get } // the selection visible to the user
    @objc optional var shuffleEnabled: Bool { get } // are songs played in random order?
    @objc optional var shuffleMode: MusicEShM { get } // the playback shuffle mode
    @objc optional var songRepeat: MusicERpt { get } // the playback repeat mode
    @objc optional var soundVolume: Int { get } // the sound output volume (0 = minimum, 100 = maximum)
    @objc optional var version: String { get } // the version of the application
    @objc optional var visualsEnabled: Bool { get } // are visuals currently being displayed?
    /// Print the specified object(s)
    @objc optional func printPrintDialog(_ printDialog: Bool, withProperties: [AnyHashable : Any]!, kind: MusicEKnd, theme: String!)
    /// Run the application
    @objc optional func run()
    /// Quit the application
    @objc optional func quit()
    /// add one or more files to a playlist
    @objc optional func add(_ x: [URL]!, to: SBObject!) -> MusicTrack
    /// reposition to beginning of current track or go to previous track if already at start of current track
    @objc optional func backTrack()
    /// convert one or more files or tracks
    @objc optional func convert(_ x: [SBObject]!) -> MusicTrack
    /// skip forward in a playing track
    @objc optional func fastForward()
    /// advance to the next track in the current playlist
    @objc optional func nextTrack()
    /// pause playback
    @objc optional func pause()
    /// play the current track or the specified track or file.
    @objc optional func playOnce(_ once: Bool)
    /// toggle the playing/paused state of the current track
    @objc optional func playpause()
    /// return to the previous track in the current playlist
    @objc optional func previousTrack()
    /// disable fast forward/rewind and resume playback, if playing.
    @objc optional func resume()
    /// skip backwards in a playing track
    @objc optional func rewind()
    /// stop playback
    @objc optional func stop()
    /// Opens an iTunes Store or audio stream URL
    @objc optional func openLocation(_ x: String!)
    /// the currently selected AirPlay device(s)
    @objc optional func setCurrentAirPlayDevices(_ currentAirPlayDevices: [MusicAirPlayDevice]!)
    /// the currently selected encoder (MP3, AIFF, WAV, etc.)
    @objc optional func setCurrentEncoder(_ currentEncoder: MusicEncoder!)
    /// the currently selected equalizer preset
    @objc optional func setCurrentEQPreset(_ currentEQPreset: MusicEQPreset!)
    /// the currently selected visual plug-in
    @objc optional func setCurrentVisual(_ currentVisual: MusicVisual!)
    /// is the equalizer enabled?
    @objc optional func setEQEnabled(_ EQEnabled: Bool)
    /// true if all AppleScript track indices should be independent of the play order of the owning playlist.
    @objc optional func setFixedIndexing(_ fixedIndexing: Bool)
    /// is this the active application?
    @objc optional func setFrontmost(_ frontmost: Bool)
    /// is the application using the entire screen?
    @objc optional func setFullScreen(_ fullScreen: Bool)
    /// has the sound output been muted?
    @objc optional func setMute(_ mute: Bool)
    /// the player’s position within the currently playing track in seconds.
    @objc optional func setPlayerPosition(_ playerPosition: Double)
    /// are songs played in random order?
    @objc optional func setShuffleEnabled(_ shuffleEnabled: Bool)
    /// the playback shuffle mode
    @objc optional func setShuffleMode(_ shuffleMode: MusicEShM)
    /// the playback repeat mode
    @objc optional func setSongRepeat(_ songRepeat: MusicERpt)
    /// the sound output volume (0 = minimum, 100 = maximum)
    @objc optional func setSoundVolume(_ soundVolume: Int)
    /// are visuals currently being displayed?
    @objc optional func setVisualsEnabled(_ visualsEnabled: Bool)
}
extension SBApplication: MusicApplication {}

// MARK: MusicItem
@objc public protocol MusicItem: SBObjectProtocol, MusicGenericMethods {
    @objc optional var container: SBObject { get } // the container of the item
    /// the id of the item
    @objc optional func id() -> Int
    @objc optional var index: Int { get } // the index of the item in internal application order
    @objc optional var name: String { get } // the name of the item
    @objc optional var persistentID: String { get } // the id of the item as a hexadecimal string. This id does not change over time.
    @objc optional var properties: [AnyHashable : Any] { get } // every property of the item
    /// download a cloud track or playlist
    @objc optional func download()
    /// reveal and select a track or playlist
    @objc optional func reveal()
    /// the name of the item
    @objc optional func setName(_ name: String!)
    /// every property of the item
    @objc optional func setProperties(_ properties: [AnyHashable : Any]!)
}
extension SBObject: MusicItem {}

// MARK: MusicAirPlayDevice
@objc public protocol MusicAirPlayDevice: MusicItem {
    @objc optional var active: Bool { get } // is the device currently being played to?
    @objc optional var available: Bool { get } // is the device currently available?
    @objc optional var kind: MusicEAPD { get } // the kind of the device
    @objc optional var networkAddress: String { get } // the network (MAC) address of the device
    /// is the device password- or passcode-protected?
    @objc optional func protected() -> Bool
    @objc optional var selected: Bool { get } // is the device currently selected?
    @objc optional var supportsAudio: Bool { get } // does the device support audio playback?
    @objc optional var supportsVideo: Bool { get } // does the device support video playback?
    @objc optional var soundVolume: Int { get } // the output volume for the device (0 = minimum, 100 = maximum)
    /// is the device currently selected?
    @objc optional func setSelected(_ selected: Bool)
    /// the output volume for the device (0 = minimum, 100 = maximum)
    @objc optional func setSoundVolume(_ soundVolume: Int)
}
extension SBObject: MusicAirPlayDevice {}

// MARK: MusicArtwork
@objc public protocol MusicArtwork: MusicItem {
    @objc optional var data: NSImage { get } // data for this artwork, in the form of a picture
    @objc optional var objectDescription: String { get } // description of artwork as a string
    @objc optional var downloaded: Bool { get } // was this artwork downloaded by Music?
    @objc optional var format: NSNumber { get } // the data format for this piece of artwork
    @objc optional var kind: Int { get } // kind or purpose of this piece of artwork
    @objc optional var rawData: Any { get } // data for this artwork, in original format
    /// data for this artwork, in the form of a picture
    @objc optional func setData(_ data: NSImage!)
    /// description of artwork as a string
    @objc optional func setObjectDescription(_ objectDescription: String!)
    /// kind or purpose of this piece of artwork
    @objc optional func setKind(_ kind: Int)
    /// data for this artwork, in original format
    @objc optional func setRawData(_ rawData: Any!)
}
extension SBObject: MusicArtwork {}

// MARK: MusicEncoder
@objc public protocol MusicEncoder: MusicItem {
    @objc optional var format: String { get } // the data format created by the encoder
}
extension SBObject: MusicEncoder {}

// MARK: MusicEQPreset
@objc public protocol MusicEQPreset: MusicItem {
    @objc optional var band1: Double { get } // the equalizer 32 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band2: Double { get } // the equalizer 64 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band3: Double { get } // the equalizer 125 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band4: Double { get } // the equalizer 250 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band5: Double { get } // the equalizer 500 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional var band6: Double { get } // the equalizer 1 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band7: Double { get } // the equalizer 2 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band8: Double { get } // the equalizer 4 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band9: Double { get } // the equalizer 8 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var band10: Double { get } // the equalizer 16 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional var modifiable: Bool { get } // can this preset be modified?
    @objc optional var preamp: Double { get } // the equalizer preamp level (-12.0 dB to +12.0 dB)
    @objc optional var updateTracks: Bool { get } // should tracks which refer to this preset be updated when the preset is renamed or deleted?
    /// the equalizer 32 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand1(_ band1: Double)
    /// the equalizer 64 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand2(_ band2: Double)
    /// the equalizer 125 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand3(_ band3: Double)
    /// the equalizer 250 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand4(_ band4: Double)
    /// the equalizer 500 Hz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand5(_ band5: Double)
    /// the equalizer 1 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand6(_ band6: Double)
    /// the equalizer 2 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand7(_ band7: Double)
    /// the equalizer 4 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand8(_ band8: Double)
    /// the equalizer 8 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand9(_ band9: Double)
    /// the equalizer 16 kHz band level (-12.0 dB to +12.0 dB)
    @objc optional func setBand10(_ band10: Double)
    /// the equalizer preamp level (-12.0 dB to +12.0 dB)
    @objc optional func setPreamp(_ preamp: Double)
    /// should tracks which refer to this preset be updated when the preset is renamed or deleted?
    @objc optional func setUpdateTracks(_ updateTracks: Bool)
}
extension SBObject: MusicEQPreset {}

// MARK: MusicPlaylist
@objc public protocol MusicPlaylist: MusicItem {
    /// Returns the Music app tracks collection.
    @objc optional func tracks() -> SBElementArray
    /// Returns the Music app artworks collection.
    @objc optional func artworks() -> SBElementArray
    @objc optional var objectDescription: String { get } // the description of the playlist
    @objc optional var disliked: Bool { get } // is this playlist disliked?
    @objc optional var duration: Int { get } // the total length of all tracks (in seconds)
    @objc optional var name: String { get } // the name of the playlist
    @objc optional var loved: Bool { get } // is this playlist loved?
    @objc optional var parent: MusicPlaylist { get } // folder which contains this playlist (if any)
    @objc optional var size: Int { get } // the total size of all tracks (in bytes)
    @objc optional var specialKind: MusicESpK { get } // special playlist kind
    @objc optional var time: String { get } // the length of all tracks in MM:SS format
    @objc optional var visible: Bool { get } // is this playlist visible in the Source list?
    /// Move playlist(s) to a new location
    @objc optional func moveTo(_ to: SBObject!)
    /// search a playlist for tracks matching the search string. Identical to entering search text in the Search field.
    @objc optional func searchFor(_ for_: String!, only: MusicESrA) -> MusicTrack
    /// the description of the playlist
    @objc optional func setObjectDescription(_ objectDescription: String!)
    /// is this playlist disliked?
    @objc optional func setDisliked(_ disliked: Bool)
    /// the name of the playlist
    @objc optional func setName(_ name: String!)
    /// is this playlist loved?
    @objc optional func setLoved(_ loved: Bool)
}
extension SBObject: MusicPlaylist {}

// MARK: MusicAudioCDPlaylist
@objc public protocol MusicAudioCDPlaylist: MusicPlaylist {
    /// Returns the Music app audio CD Tracks collection.
    @objc optional func audioCDTracks() -> SBElementArray
    @objc optional var artist: String { get } // the artist of the CD
    @objc optional var compilation: Bool { get } // is this CD a compilation album?
    @objc optional var composer: String { get } // the composer of the CD
    @objc optional var discCount: Int { get } // the total number of discs in this CD’s album
    @objc optional var discNumber: Int { get } // the index of this CD disc in the source album
    @objc optional var genre: String { get } // the genre of the CD
    @objc optional var year: Int { get } // the year the album was recorded/released
    /// the artist of the CD
    @objc optional func setArtist(_ artist: String!)
    /// is this CD a compilation album?
    @objc optional func setCompilation(_ compilation: Bool)
    /// the composer of the CD
    @objc optional func setComposer(_ composer: String!)
    /// the total number of discs in this CD’s album
    @objc optional func setDiscCount(_ discCount: Int)
    /// the index of this CD disc in the source album
    @objc optional func setDiscNumber(_ discNumber: Int)
    /// the genre of the CD
    @objc optional func setGenre(_ genre: String!)
    /// the year the album was recorded/released
    @objc optional func setYear(_ year: Int)
}
extension SBObject: MusicAudioCDPlaylist {}

// MARK: MusicLibraryPlaylist
@objc public protocol MusicLibraryPlaylist: MusicPlaylist {
    /// Returns the Music app file Tracks collection.
    @objc optional func fileTracks() -> SBElementArray
    /// Returns the Music app URL Tracks collection.
    @objc optional func URLTracks() -> SBElementArray
    /// Returns the Music app shared Tracks collection.
    @objc optional func sharedTracks() -> SBElementArray
}
extension SBObject: MusicLibraryPlaylist {}

// MARK: MusicRadioTunerPlaylist
@objc public protocol MusicRadioTunerPlaylist: MusicPlaylist {
    /// Returns the Music app URL Tracks collection.
    @objc optional func URLTracks() -> SBElementArray
}
extension SBObject: MusicRadioTunerPlaylist {}

// MARK: MusicSource
@objc public protocol MusicSource: MusicItem {
    /// Returns the Music app audio CD Playlists collection.
    @objc optional func audioCDPlaylists() -> SBElementArray
    /// Returns the Music app library Playlists collection.
    @objc optional func libraryPlaylists() -> SBElementArray
    /// Returns the Music app playlists collection.
    @objc optional func playlists() -> SBElementArray
    /// Returns the Music app radio Tuner Playlists collection.
    @objc optional func radioTunerPlaylists() -> SBElementArray
    /// Returns the Music app subscription Playlists collection.
    @objc optional func subscriptionPlaylists() -> SBElementArray
    /// Returns the Music app user Playlists collection.
    @objc optional func userPlaylists() -> SBElementArray
    @objc optional var capacity: Int64 { get } // the total size of the source if it has a fixed size
    @objc optional var freeSpace: Int64 { get } // the free space on the source if it has a fixed size
    @objc optional var kind: MusicESrc { get }
}
extension SBObject: MusicSource {}

// MARK: MusicSubscriptionPlaylist
@objc public protocol MusicSubscriptionPlaylist: MusicPlaylist {
    /// Returns the Music app file Tracks collection.
    @objc optional func fileTracks() -> SBElementArray
    /// Returns the Music app URL Tracks collection.
    @objc optional func URLTracks() -> SBElementArray
}
extension SBObject: MusicSubscriptionPlaylist {}

// MARK: MusicTrack
@objc public protocol MusicTrack: MusicItem {
    /// Returns the Music app artworks collection.
    @objc optional func artworks() -> SBElementArray
    @objc optional var album: String { get } // the album name of the track
    @objc optional var albumArtist: String { get } // the album artist of the track
    @objc optional var albumDisliked: Bool { get } // is the album for this track disliked?
    @objc optional var albumLoved: Bool { get } // is the album for this track loved?
    @objc optional var albumRating: Int { get } // the rating of the album for this track (0 to 100)
    @objc optional var albumRatingKind: MusicERtK { get } // the rating kind of the album rating for this track
    @objc optional var artist: String { get } // the artist/source of the track
    @objc optional var bitRate: Int { get } // the bit rate of the track (in kbps)
    @objc optional var bookmark: Double { get } // the bookmark time of the track in seconds
    @objc optional var bookmarkable: Bool { get } // is the playback position for this track remembered?
    @objc optional var bpm: Int { get } // the tempo of this track in beats per minute
    @objc optional var category: String { get } // the category of the track
    @objc optional var cloudStatus: MusicEClS { get } // the iCloud status of the track
    @objc optional var comment: String { get } // freeform notes about the track
    @objc optional var compilation: Bool { get } // is this track from a compilation album?
    @objc optional var composer: String { get } // the composer of the track
    @objc optional var databaseID: Int { get } // the common, unique ID for this track. If two tracks in different playlists have the same database ID, they are sharing the same data.
    @objc optional var dateAdded: Date { get } // the date the track was added to the playlist
    @objc optional var objectDescription: String { get } // the description of the track
    @objc optional var discCount: Int { get } // the total number of discs in the source album
    @objc optional var discNumber: Int { get } // the index of the disc containing this track on the source album
    @objc optional var disliked: Bool { get } // is this track disliked?
    @objc optional var downloaderAppleID: String { get } // the Apple ID of the person who downloaded this track
    @objc optional var downloaderName: String { get } // the name of the person who downloaded this track
    @objc optional var duration: Double { get } // the length of the track in seconds
    @objc optional var enabled: Bool { get } // is this track checked for playback?
    @objc optional var episodeID: String { get } // the episode ID of the track
    @objc optional var episodeNumber: Int { get } // the episode number of the track
    @objc optional var EQ: String { get } // the name of the EQ preset of the track
    @objc optional var finish: Double { get } // the stop time of the track in seconds
    @objc optional var gapless: Bool { get } // is this track from a gapless album?
    @objc optional var genre: String { get } // the music/audio genre (category) of the track
    @objc optional var grouping: String { get } // the grouping (piece) of the track. Generally used to denote movements within a classical work.
    @objc optional var kind: String { get } // a text description of the track
    @objc optional var longDescription: String { get } // the long description of the track
    @objc optional var loved: Bool { get } // is this track loved?
    @objc optional var lyrics: String { get } // the lyrics of the track
    @objc optional var mediaKind: MusicEMdK { get } // the media kind of the track
    @objc optional var modificationDate: Date { get } // the modification date of the content of this track
    @objc optional var movement: String { get } // the movement name of the track
    @objc optional var movementCount: Int { get } // the total number of movements in the work
    @objc optional var movementNumber: Int { get } // the index of the movement in the work
    @objc optional var playedCount: Int { get } // number of times this track has been played
    @objc optional var playedDate: Date { get } // the date and time this track was last played
    @objc optional var purchaserAppleID: String { get } // the Apple ID of the person who purchased this track
    @objc optional var purchaserName: String { get } // the name of the person who purchased this track
    @objc optional var rating: Int { get } // the rating of this track (0 to 100)
    @objc optional var ratingKind: MusicERtK { get } // the rating kind of this track
    @objc optional var releaseDate: Date { get } // the release date of this track
    @objc optional var sampleRate: Int { get } // the sample rate of the track (in Hz)
    @objc optional var seasonNumber: Int { get } // the season number of the track
    @objc optional var shufflable: Bool { get } // is this track included when shuffling?
    @objc optional var skippedCount: Int { get } // number of times this track has been skipped
    @objc optional var skippedDate: Date { get } // the date and time this track was last skipped
    @objc optional var show: String { get } // the show name of the track
    @objc optional var sortAlbum: String { get } // override string to use for the track when sorting by album
    @objc optional var sortArtist: String { get } // override string to use for the track when sorting by artist
    @objc optional var sortAlbumArtist: String { get } // override string to use for the track when sorting by album artist
    @objc optional var sortName: String { get } // override string to use for the track when sorting by name
    @objc optional var sortComposer: String { get } // override string to use for the track when sorting by composer
    @objc optional var sortShow: String { get } // override string to use for the track when sorting by show name
    @objc optional var size: Int64 { get } // the size of the track (in bytes)
    @objc optional var start: Double { get } // the start time of the track in seconds
    @objc optional var time: String { get } // the length of the track in MM:SS format
    @objc optional var trackCount: Int { get } // the total number of tracks on the source album
    @objc optional var trackNumber: Int { get } // the index of the track on the source album
    @objc optional var unplayed: Bool { get } // is this track unplayed?
    @objc optional var volumeAdjustment: Int { get } // relative volume adjustment of the track (-100% to 100%)
    @objc optional var work: String { get } // the work name of the track
    @objc optional var year: Int { get } // the year the track was recorded/released
    /// the album name of the track
    @objc optional func setAlbum(_ album: String!)
    /// the album artist of the track
    @objc optional func setAlbumArtist(_ albumArtist: String!)
    /// is the album for this track disliked?
    @objc optional func setAlbumDisliked(_ albumDisliked: Bool)
    /// is the album for this track loved?
    @objc optional func setAlbumLoved(_ albumLoved: Bool)
    /// the rating of the album for this track (0 to 100)
    @objc optional func setAlbumRating(_ albumRating: Int)
    /// the artist/source of the track
    @objc optional func setArtist(_ artist: String!)
    /// the bookmark time of the track in seconds
    @objc optional func setBookmark(_ bookmark: Double)
    /// is the playback position for this track remembered?
    @objc optional func setBookmarkable(_ bookmarkable: Bool)
    /// the tempo of this track in beats per minute
    @objc optional func setBpm(_ bpm: Int)
    /// the category of the track
    @objc optional func setCategory(_ category: String!)
    /// freeform notes about the track
    @objc optional func setComment(_ comment: String!)
    /// is this track from a compilation album?
    @objc optional func setCompilation(_ compilation: Bool)
    /// the composer of the track
    @objc optional func setComposer(_ composer: String!)
    /// the description of the track
    @objc optional func setObjectDescription(_ objectDescription: String!)
    /// the total number of discs in the source album
    @objc optional func setDiscCount(_ discCount: Int)
    /// the index of the disc containing this track on the source album
    @objc optional func setDiscNumber(_ discNumber: Int)
    /// is this track disliked?
    @objc optional func setDisliked(_ disliked: Bool)
    /// is this track checked for playback?
    @objc optional func setEnabled(_ enabled: Bool)
    /// the episode ID of the track
    @objc optional func setEpisodeID(_ episodeID: String!)
    /// the episode number of the track
    @objc optional func setEpisodeNumber(_ episodeNumber: Int)
    /// the name of the EQ preset of the track
    @objc optional func setEQ(_ EQ: String!)
    /// the stop time of the track in seconds
    @objc optional func setFinish(_ finish: Double)
    /// is this track from a gapless album?
    @objc optional func setGapless(_ gapless: Bool)
    /// the music/audio genre (category) of the track
    @objc optional func setGenre(_ genre: String!)
    /// the grouping (piece) of the track. Generally used to denote movements within a classical work.
    @objc optional func setGrouping(_ grouping: String!)
    /// the long description of the track
    @objc optional func setLongDescription(_ longDescription: String!)
    /// is this track loved?
    @objc optional func setLoved(_ loved: Bool)
    /// the lyrics of the track
    @objc optional func setLyrics(_ lyrics: String!)
    /// the media kind of the track
    @objc optional func setMediaKind(_ mediaKind: MusicEMdK)
    /// the movement name of the track
    @objc optional func setMovement(_ movement: String!)
    /// the total number of movements in the work
    @objc optional func setMovementCount(_ movementCount: Int)
    /// the index of the movement in the work
    @objc optional func setMovementNumber(_ movementNumber: Int)
    /// number of times this track has been played
    @objc optional func setPlayedCount(_ playedCount: Int)
    /// the date and time this track was last played
    @objc optional func setPlayedDate(_ playedDate: Date!)
    /// the rating of this track (0 to 100)
    @objc optional func setRating(_ rating: Int)
    /// the season number of the track
    @objc optional func setSeasonNumber(_ seasonNumber: Int)
    /// is this track included when shuffling?
    @objc optional func setShufflable(_ shufflable: Bool)
    /// number of times this track has been skipped
    @objc optional func setSkippedCount(_ skippedCount: Int)
    /// the date and time this track was last skipped
    @objc optional func setSkippedDate(_ skippedDate: Date!)
    /// the show name of the track
    @objc optional func setShow(_ show: String!)
    /// override string to use for the track when sorting by album
    @objc optional func setSortAlbum(_ sortAlbum: String!)
    /// override string to use for the track when sorting by artist
    @objc optional func setSortArtist(_ sortArtist: String!)
    /// override string to use for the track when sorting by album artist
    @objc optional func setSortAlbumArtist(_ sortAlbumArtist: String!)
    /// override string to use for the track when sorting by name
    @objc optional func setSortName(_ sortName: String!)
    /// override string to use for the track when sorting by composer
    @objc optional func setSortComposer(_ sortComposer: String!)
    /// override string to use for the track when sorting by show name
    @objc optional func setSortShow(_ sortShow: String!)
    /// the start time of the track in seconds
    @objc optional func setStart(_ start: Double)
    /// the total number of tracks on the source album
    @objc optional func setTrackCount(_ trackCount: Int)
    /// the index of the track on the source album
    @objc optional func setTrackNumber(_ trackNumber: Int)
    /// is this track unplayed?
    @objc optional func setUnplayed(_ unplayed: Bool)
    /// relative volume adjustment of the track (-100% to 100%)
    @objc optional func setVolumeAdjustment(_ volumeAdjustment: Int)
    /// the work name of the track
    @objc optional func setWork(_ work: String!)
    /// the year the track was recorded/released
    @objc optional func setYear(_ year: Int)
}
extension SBObject: MusicTrack {}

// MARK: MusicAudioCDTrack
@objc public protocol MusicAudioCDTrack: MusicTrack {
    @objc optional var location: URL { get } // the location of the file represented by this track
}
extension SBObject: MusicAudioCDTrack {}

// MARK: MusicFileTrack
@objc public protocol MusicFileTrack: MusicTrack {
    @objc optional var location: URL { get } // the location of the file represented by this track
    /// update file track information from the current information in the track’s file
    @objc optional func refresh()
    /// the location of the file represented by this track
    @objc optional func setLocation(_ location: URL!)
}
extension SBObject: MusicFileTrack {}

// MARK: MusicSharedTrack
@objc public protocol MusicSharedTrack: MusicTrack {
}
extension SBObject: MusicSharedTrack {}

// MARK: MusicURLTrack
@objc public protocol MusicURLTrack: MusicTrack {
    @objc optional var address: String { get } // the URL for this track
    /// the URL for this track
    @objc optional func setAddress(_ address: String!)
}
extension SBObject: MusicURLTrack {}

// MARK: MusicUserPlaylist
@objc public protocol MusicUserPlaylist: MusicPlaylist {
    /// Returns the Music app file Tracks collection.
    @objc optional func fileTracks() -> SBElementArray
    /// Returns the Music app URL Tracks collection.
    @objc optional func URLTracks() -> SBElementArray
    /// Returns the Music app shared Tracks collection.
    @objc optional func sharedTracks() -> SBElementArray
    @objc optional var shared: Bool { get } // is this playlist shared?
    @objc optional var smart: Bool { get } // is this a Smart Playlist?
    @objc optional var genius: Bool { get } // is this a Genius Playlist?
    /// is this playlist shared?
    @objc optional func setShared(_ shared: Bool)
}
extension SBObject: MusicUserPlaylist {}

// MARK: MusicFolderPlaylist
@objc public protocol MusicFolderPlaylist: MusicUserPlaylist {
}
extension SBObject: MusicFolderPlaylist {}

// MARK: MusicVisual
@objc public protocol MusicVisual: MusicItem {
}
extension SBObject: MusicVisual {}

// MARK: MusicWindow
@objc public protocol MusicWindow: MusicItem {
    @objc optional var bounds: NSRect { get } // the boundary rectangle for the window
    @objc optional var closeable: Bool { get } // does the window have a close button?
    @objc optional var collapseable: Bool { get } // does the window have a collapse button?
    @objc optional var collapsed: Bool { get } // is the window collapsed?
    @objc optional var fullScreen: Bool { get } // is the window full screen?
    @objc optional var position: NSPoint { get } // the upper left position of the window
    @objc optional var resizable: Bool { get } // is the window resizable?
    @objc optional var visible: Bool { get } // is the window visible?
    @objc optional var zoomable: Bool { get } // is the window zoomable?
    @objc optional var zoomed: Bool { get } // is the window zoomed?
    /// the boundary rectangle for the window
    @objc optional func setBounds(_ bounds: NSRect)
    /// is the window collapsed?
    @objc optional func setCollapsed(_ collapsed: Bool)
    /// is the window full screen?
    @objc optional func setFullScreen(_ fullScreen: Bool)
    /// the upper left position of the window
    @objc optional func setPosition(_ position: NSPoint)
    /// is the window visible?
    @objc optional func setVisible(_ visible: Bool)
    /// is the window zoomed?
    @objc optional func setZoomed(_ zoomed: Bool)
}
extension SBObject: MusicWindow {}

// MARK: MusicBrowserWindow
@objc public protocol MusicBrowserWindow: MusicWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: MusicPlaylist { get } // the playlist currently displayed in the window
    /// the playlist currently displayed in the window
    @objc optional func setView(_ view: MusicPlaylist!)
}
extension SBObject: MusicBrowserWindow {}

// MARK: MusicEQWindow
@objc public protocol MusicEQWindow: MusicWindow {
}
extension SBObject: MusicEQWindow {}

// MARK: MusicMiniplayerWindow
@objc public protocol MusicMiniplayerWindow: MusicWindow {
}
extension SBObject: MusicMiniplayerWindow {}

// MARK: MusicPlaylistWindow
@objc public protocol MusicPlaylistWindow: MusicWindow {
    @objc optional var selection: SBObject { get } // the selected tracks
    @objc optional var view: MusicPlaylist { get } // the playlist displayed in the window
}
extension SBObject: MusicPlaylistWindow {}

// MARK: MusicVideoWindow
@objc public protocol MusicVideoWindow: MusicWindow {
}
extension SBObject: MusicVideoWindow {}
