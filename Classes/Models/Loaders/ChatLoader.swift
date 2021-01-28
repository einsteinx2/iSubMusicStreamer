//
//  ChatLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class ChatLoader: APILoader {
    let serverId: Int
    private(set) var chatMessages = [ChatMessage]()
    
    init(serverId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chat }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getChatMessages")
    }
    
    override func processResponse(data: Data) {
        self.chatMessages.removeAll()
        guard let root = validate(data: data) else { return }
        guard let chatMessages = validateChild(parent: root, childTag: "chatMessages") else { return }
        
        chatMessages.iterate("chatMessage") { e, _ in
            self.chatMessages.append(ChatMessage(serverId: self.serverId, element: e))
        }
        
        informDelegateLoadingFinished()
    }
}
