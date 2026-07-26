//
//  AsyncChatLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncChatLoader: AsyncAPILoader<[ChatMessage]> {
    let serverId: Int
    
    init(serverId: Int) {
        self.serverId = serverId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chat }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getChatMessages)
    }
    
    override func processResponse(data: Data) async throws -> [ChatMessage] {
        try Task.checkCancellation()
        
        let chatMessages = try require(decodeSubsonicResponse(data: data).chatMessages, "chatMessages")

        try Task.checkCancellation()

        return (chatMessages.chatMessage?.values ?? []).map { ChatMessage(serverId: serverId, dto: $0) }
    }
}
