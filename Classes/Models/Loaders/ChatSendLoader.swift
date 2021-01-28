//
//  ChatSendLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class ChatSendLoader: APILoader {
    let serverId: Int
    let message: String
    
    init(serverId: Int, message: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.message = message
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chatSend }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "addChatMessage", parameters: ["message": message])
    }
    
    override func processResponse(data: Data) {
        guard let _ = validate(data: data) else { return }
        informDelegateLoadingFinished()
    }
}
