//
//  DownloadedSongPathComponent.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class DownloadedSongPathComponent: Codable, CustomStringConvertible {
    let level: Int
    let maxLevel: Int
    let pathComponent: String
    let parentPathComponent: String?
    let serverId: Int
    let songId: Int
    
    init(level: Int, maxLevel: Int, pathComponent: String, parentPathComponent: String?, serverId: Int, songId: Int) {
        self.level = level
        self.maxLevel = maxLevel
        self.pathComponent = pathComponent
        self.parentPathComponent = parentPathComponent
        self.serverId = serverId
        self.songId = songId
    }
}
