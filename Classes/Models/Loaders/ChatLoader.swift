//
//  ChatLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class ChatLoader: SUSLoader {
    var serverId = Settings.shared().currentServerId
    
    var chatMessages = [ChatMessage]()
    
    override var type: SUSLoaderType { SUSLoaderType_Chat }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getChatMessages", parameters: nil) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
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
