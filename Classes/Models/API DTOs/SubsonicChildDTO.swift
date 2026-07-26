//
//  SubsonicChildDTO.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

/// Mirrors the Subsonic `<child>` element and its aliases (`<song>`, `<entry>`,
/// `<match>`, `<album>` in albumList/searchResult2). Backs Song, FolderAlbum, and
/// NowPlayingSong construction.
struct ChildDTO: Decodable, Equatable {
    let id: SubsonicID
    let parent: SubsonicID?
    let isDir: Bool?
    let title: String?
    let album: String?
    let artist: String?
    let coverArt: SubsonicID?
    let albumId: SubsonicID?
    let artistId: SubsonicID?
    let track: Int?
    let year: Int?
    let discNumber: Int?
    let genre: String?
    let size: Int?
    let duration: Int?
    let bitRate: Int?
    let playCount: Int?
    let userRating: Int?
    let averageRating: Double?
    let path: String?
    let suffix: String?
    let transcodedSuffix: String?
    let isVideo: Bool?
    let created: Date?
    let starred: Date?

    // getNowPlaying entries only
    let username: String?
    let minutesAgo: Int?
    let playerId: SubsonicID?
    let playerName: String?
}
