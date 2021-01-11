//
//  DownloadedSongPathComponent.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class DownloadedSongPathComponent: NSObject, NSCopying, Codable {
    @objc let level: Int
    @objc let maxLevel: Int
    @objc let pathComponent: String
    @objc let parentPathComponent: String?
    @objc let serverId: Int
    @objc let songId: Int
    
    @objc init(level: Int, maxLevel: Int, pathComponent: String, parentPathComponent: String?, serverId: Int, songId: Int) {
        self.level = level
        self.maxLevel = maxLevel
        self.pathComponent = pathComponent
        self.parentPathComponent = parentPathComponent
        self.serverId = serverId
        self.songId = songId
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return DownloadedSongPathComponent(level: level, maxLevel: maxLevel, pathComponent: pathComponent, parentPathComponent: parentPathComponent, serverId: serverId, songId: songId)
    }
    
    override var description: String {
        "\(super.description): level: \(level), maxLevel: \(maxLevel), pathComponent: \(pathComponent), parentPathComponent: \(parentPathComponent ?? "nil"), serverId: \(serverId), songId: \(songId)"
    }
}
