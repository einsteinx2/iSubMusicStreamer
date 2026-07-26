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
    let songId: String
    let username: String
    let minutesAgo: Int
    let playerId: Int
    let playerName: String
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.songId = element.attribute("id").stringXML
        self.username = element.attribute("username").stringXML
        self.minutesAgo = element.attribute("minutesAgo").intXML
        self.playerId = element.attribute("playerId").intXML
        self.playerName = element.attribute("playerName").stringXML
    }

    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel)
    init(serverId: Int, dto: ChildDTO) {
        self.serverId = serverId
        self.songId = dto.id.value
        self.username = dto.username ?? "nil"
        self.minutesAgo = dto.minutesAgo ?? 0
        self.playerId = Int(dto.playerId?.value ?? "") ?? 0
        self.playerName = dto.playerName ?? "nil"
    }
}
