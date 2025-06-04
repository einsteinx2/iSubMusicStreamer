//
//  AsyncChatSendLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncChatSendLoader: AsyncAPILoader<Void> {
    let serverId: Int
    let message: String
    
    init(serverId: Int, message: String) {
        self.serverId = serverId
        self.message = message
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chatSend }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .addChatMessage, parameters: ["message": message])
    }
    
    override func processResponse(data: Data) async throws {
        guard let _ = try await validate(data: data) else {
            throw APIError.responseNotXML
        }
    }
}
