//
//  DownloadedSongPathComponent.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class DownloadedSongPathComponent: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc let songId: Int
    @objc let level: Int
    @objc let pathComponent: String
    
    @objc init(serverId: Int, songId: Int, level: Int, pathComponent: String) {
        self.serverId = serverId
        self.songId = songId
        self.level = level
        self.pathComponent = pathComponent
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return DownloadedSongPathComponent(serverId: serverId, songId: songId, level: level, pathComponent: pathComponent)
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), songId: \(songId), level: \(level), pathComponent: \(pathComponent)"
    }
}
