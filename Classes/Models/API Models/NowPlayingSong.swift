//
//  NowPlayingSong.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class NowPlayingSong: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc let songId: Int
    @objc let username: String
    @objc let minutesAgo: Int
    @objc let playerId: Int
    @objc let playerName: String
    
    @objc init(serverId: Int, songId: Int, username: String, minutesAgo: Int, playerId: Int, playerName: String) {
        self.serverId = serverId
        self.songId = songId
        self.username = username
        self.minutesAgo = minutesAgo
        self.playerId = playerId
        self.playerName = playerName
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.songId = element.attribute("id").intXML
        self.username = element.attribute("username").stringXML
        self.minutesAgo = element.attribute("minutesAgo").intXML
        self.playerId = element.attribute("playerId").intXML
        self.playerName = element.attribute("playerName").stringXML
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        NowPlayingSong(serverId: serverId, songId: songId, username: username, minutesAgo: minutesAgo, playerId: playerId, playerName: playerName)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? NowPlayingSong {
            return self === object || (serverId == object.serverId && songId == object.songId)
        }
        return false
    }
}
