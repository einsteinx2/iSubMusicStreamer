//
//  ChatMessage.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct ChatMessage: Equatable {
    let serverId: Int
    let timestamp: TimeInterval
    let username: String
    let message: String
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.timestamp = TimeInterval(element.attribute("time").intXML) / 1000
        self.username = element.attribute("username").stringXML
        self.message = element.attribute("message").stringXML
    }
}
