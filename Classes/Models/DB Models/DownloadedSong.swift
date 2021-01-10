//
//  DownloadedSong.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class DownloadedSong: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc let songId: Int
    @objc let path: String
    @objc var finished: Bool = false
    @objc var pinned: Bool = false
    @objc var size: Int = 0
    @objc var cachedDate: Date? = nil
    @objc var playedDate: Date? = nil
    
    @objc init(serverId: Int, songId: Int, path: String, finished: Bool, pinned: Bool, size: Int, cachedDate: Date?, playedDate: Date?) {
        self.serverId = serverId
        self.songId = songId
        self.path = path
        self.finished = finished
        self.pinned = pinned
        self.size = size
        self.cachedDate = cachedDate
        self.playedDate = playedDate
        super.init()
    }
    
    @objc init(serverId: Int, songId: Int, path: String) {
        self.serverId = serverId
        self.songId = songId
        self.path = path
        super.init()
    }
    
    @objc init(song: Song) {
        self.serverId = song.serverId
        self.songId = song.id
        self.path = song.path
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return DownloadedSong(serverId: serverId, songId: songId, path: path, finished: finished, pinned: pinned, size: size, cachedDate: cachedDate, playedDate: playedDate)
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), songId: \(songId), path: \(path), finished: \(finished), pinned: \(pinned), size: \(size), cachedDate: \(cachedDate?.description ?? "nil"), playedDate: \(playedDate?.description ?? "nil")"
    }
}