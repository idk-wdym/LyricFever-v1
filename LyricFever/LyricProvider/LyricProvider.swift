//
//  LyricProvider.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-25.
//

protocol LyricProvider {
    var providerName: String { get }
    
    @MainActor
    /// Fetches network lyrics.
    func fetchNetworkLyrics(trackName: String, trackID: String, currentlyPlayingArtist: String?, currentAlbumName: String? ) async throws -> NetworkFetchReturn

    @MainActor
    /// Searches provider-specific catalogues for candidate songs matching the supplied metadata.
    func search(trackName: String, artistName: String) async throws -> [SongResult]
}

