//
//  SubsonicBrowsingDTOs.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Payloads for the browsing endpoints: getIndexes, getMusicDirectory (folder
// hierarchy) and getArtists, getArtist, getAlbum (ID3 tag hierarchy).

/// getIndexes
struct IndexesDTO: Decodable, Equatable {
    let ignoredArticles: String?
    let shortcut: LenientArray<FolderArtistDTO>?
    let index: LenientArray<IndexDTO<FolderArtistDTO>>?
    // Some servers list loose media files at the music folder root
    let child: LenientArray<ChildDTO>?
}

/// One alphabetical section inside getIndexes/getArtists
struct IndexDTO<A: Decodable & Equatable>: Decodable, Equatable {
    let name: String?
    let artist: LenientArray<A>?
}

/// Artist as a folder (getIndexes index/shortcut, searchResult2)
struct FolderArtistDTO: Decodable, Equatable {
    let id: SubsonicID
    let name: String?
    let userRating: Int?
    let averageRating: Double?
    let starred: Date?
}

/// getMusicDirectory
struct DirectoryDTO: Decodable, Equatable {
    let id: SubsonicID?
    let parent: SubsonicID?
    let name: String?
    let playCount: Int?
    let child: LenientArray<ChildDTO>?
}

/// getArtists
struct ArtistsID3DTO: Decodable, Equatable {
    let ignoredArticles: String?
    let index: LenientArray<IndexDTO<ArtistID3DTO>>?
}

/// ID3 artist (getArtists, getArtist, searchResult3); only getArtist includes albums
struct ArtistID3DTO: Decodable, Equatable {
    let id: SubsonicID
    let name: String?
    let coverArt: SubsonicID?
    let artistImageUrl: String?
    let albumCount: Int?
    let starred: Date?
    let album: LenientArray<AlbumID3DTO>?
}

/// ID3 album (getArtist, getAlbum, searchResult3); only getAlbum includes songs
struct AlbumID3DTO: Decodable, Equatable {
    let id: SubsonicID
    let name: String?
    let coverArt: SubsonicID?
    let artistId: SubsonicID?
    let artist: String?
    let songCount: Int?
    let duration: Int?
    let playCount: Int?
    let year: Int?
    let genre: String?
    let created: Date?
    let starred: Date?
    let song: LenientArray<ChildDTO>?
}
