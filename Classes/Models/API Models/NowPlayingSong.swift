//
//  NowPlayingSong.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct NowPlayingSong: Codable, Equatable {
    let serverId: Int
    let songId: Int
    let username: String
    let minutesAgo: Int
    let playerId: Int
    let playerName: String
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.songId = element.attribute("id").intXML
        self.username = element.attribute("username").stringXML
        self.minutesAgo = element.attribute("minutesAgo").intXML
        self.playerId = element.attribute("playerId").intXML
        self.playerName = element.attribute("playerName").stringXML
    }
}
