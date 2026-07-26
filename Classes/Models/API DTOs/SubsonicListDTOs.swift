//
//  SubsonicListDTOs.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Payloads for the list-shaped endpoints: getAlbumList, getRandomSongs, search
// (all three variants), getNowPlaying, and playlists.

/// getAlbumList (entries are folder-album shaped, i.e. child elements)
struct AlbumListDTO: Decodable, Equatable {
    let album: LenientArray<ChildDTO>?
}

/// getRandomSongs
struct SongListDTO: Decodable, Equatable {
    let song: LenientArray<ChildDTO>?
}

/// search (original API, songs only)
struct SearchResultDTO: Decodable, Equatable {
    let match: LenientArray<ChildDTO>?
}

/// search2 (folder hierarchy)
struct SearchResult2DTO: Decodable, Equatable {
    let artist: LenientArray<FolderArtistDTO>?
    let album: LenientArray<ChildDTO>?
    let song: LenientArray<ChildDTO>?
}

/// search3 (ID3 tag hierarchy)
struct SearchResult3DTO: Decodable, Equatable {
    let artist: LenientArray<ArtistID3DTO>?
    let album: LenientArray<AlbumID3DTO>?
    let song: LenientArray<ChildDTO>?
}

/// getNowPlaying
struct NowPlayingDTO: Decodable, Equatable {
    let entry: LenientArray<ChildDTO>?
}

/// getPlaylists
struct PlaylistsDTO: Decodable, Equatable {
    let playlist: LenientArray<PlaylistDTO>?
}

/// Playlist header (getPlaylists); getPlaylist adds the entry children
struct PlaylistDTO: Decodable, Equatable {
    let id: SubsonicID
    let name: String?
    let comment: String?
    let owner: String?
    let isPublic: Bool?
    let songCount: Int?
    let duration: Int?
    let coverArt: SubsonicID?
    let created: Date?
    let changed: Date?
    let entry: LenientArray<ChildDTO>?

    enum CodingKeys: String, CodingKey {
        case id, name, comment, owner, songCount, duration, coverArt, created, changed, entry
        case isPublic = "public"
    }
}
