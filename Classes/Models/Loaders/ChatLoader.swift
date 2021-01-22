//
//  ChatLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class ChatLoader: AbstractAPILoader {
    let serverId: Int
    private(set) var chatMessages = [ChatMessage]()
    
    init(serverId: Int, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chat }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getChatMessages")
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                chatMessages.removeAll()
                root.iterate("chatMessages.chatMessage") { e in
                    self.chatMessages.append(ChatMessage(serverId: self.serverId, element: e))
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
