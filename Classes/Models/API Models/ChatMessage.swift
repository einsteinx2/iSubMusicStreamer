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
    
    // Reproduces the legacy XML init's defaults exactly (incl. the "nil" sentinel)
    init(serverId: Int, dto: ChatMessageDTO) {
        self.serverId = serverId
        self.timestamp = TimeInterval(dto.time ?? 0) / 1000
        self.username = dto.username ?? "nil"
        self.message = dto.message ?? "nil"
    }
}
