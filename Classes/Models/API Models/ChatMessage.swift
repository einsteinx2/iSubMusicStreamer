//
//  ChatMessage.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ChatMessage: NSObject, NSCopying {
    @objc let serverId: Int
    @objc let timestamp: TimeInterval
    @objc let username: String
    @objc let message: String
    
    @objc init(serverId: Int, timestamp: TimeInterval, username: String, message: String) {
        self.serverId = serverId
        self.timestamp = timestamp
        self.username = username
        self.message = message
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.timestamp = TimeInterval(element.attribute("time").intXML) / 1000
        self.username = element.attribute("username").stringXML
        self.message = element.attribute("message").stringXML
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        ChatMessage(serverId: serverId, timestamp: timestamp, username: username, message: message)
    }
    
    override var description: String {
        "\(super.description): serverId: \(serverId), timestamp: \(timestamp), username: \(username), message: \(message)"
    }
}
