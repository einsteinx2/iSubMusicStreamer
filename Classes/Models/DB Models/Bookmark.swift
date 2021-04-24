//
//  Bookmark.swift
//  iSub
//
//  Created by Benjamin Baron on 2/2/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct Bookmark: Codable, Equatable {
    let id: Int
    let songServerId: Int
    let songId: String
    let localPlaylistId: Int
    let songIndex: Int
    let offsetInSeconds: Double
    let offsetInBytes: Int
    
    init(id: Int, song: Song, localPlaylist: LocalPlaylist, songIndex: Int, offsetInSeconds: Double, offsetInBytes: Int) {
        self.id = id
        self.songServerId = song.serverId
        self.songId = song.id
        self.localPlaylistId = localPlaylist.id
        self.songIndex = songIndex
        self.offsetInSeconds = offsetInSeconds
        self.offsetInBytes = offsetInBytes
    }
}
