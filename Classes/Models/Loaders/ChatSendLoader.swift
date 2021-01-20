//
//  ChatSendLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class ChatSendLoader: APILoader {
    var serverId = Settings.shared().currentServerId
    private let message: String
    
    init(message: String) {
        self.message = message
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .chatSend }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "addChatMessage", parameters: ["message": message])
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                informDelegateLoadingFinished()
            }
        }
    }
}
