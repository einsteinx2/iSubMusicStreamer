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
        
        guard let root = try await validate(data: data), let chatMessages = try await validateChild(parent: root, childTag: "chatMessages") else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()

        var messages = [ChatMessage]()
        for try await element in chatMessages.iterate("chatMessage") {
            messages.append(ChatMessage(serverId: serverId, element: element))
        }

        return messages
    }
}
