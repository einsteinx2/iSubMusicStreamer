//
//  NowPlayingSong.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class NowPlayingSong: Codable, CustomStringConvertible {
    let serverId: Int
    let songId: Int
    let username: String
    let minutesAgo: Int
    let playerId: Int
    let playerName: String
    
    init(serverId: Int, songId: Int, username: String, minutesAgo: Int, playerId: Int, playerName: String) {
        self.serverId = serverId
        self.songId = songId
        self.username = username
        self.minutesAgo = minutesAgo
        self.playerId = playerId
        self.playerName = playerName
    }
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.songId = element.attribute("id").intXML
        self.username = element.attribute("username").stringXML
        self.minutesAgo = element.attribute("minutesAgo").intXML
        self.playerId = element.attribute("playerId").intXML
        self.playerName = element.attribute("playerName").stringXML
    }

    static func ==(lhs: NowPlayingSong, rhs: NowPlayingSong) -> Bool {
        return lhs === rhs || (lhs.serverId == rhs.serverId && lhs.songId == rhs.songId)
    }
}
