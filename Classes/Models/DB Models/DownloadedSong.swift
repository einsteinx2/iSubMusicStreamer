//
//  DownloadedSong.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct DownloadedSong: Codable, Equatable {
    let serverId: Int
    let songId: String
    let path: String
    var isFinished: Bool = false
    var isPinned: Bool = false
    var size: Int = 0
    var downloadedDate: Date? = nil
    var playedDate: Date? = nil

    init(song: Song) {
        self.serverId = song.serverId
        self.songId = song.id
        self.path = song.path
    }
    
    static func ==(lhs: DownloadedSong, rhs: DownloadedSong) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.songId == rhs.songId
    }
}
