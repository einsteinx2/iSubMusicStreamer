//
//  ChatSendLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class ChatSendLoader: APILoader {
    override var type: APILoaderType { .chatSend }
    
    private let message: String
    
    init(message: String) {
        self.message = message
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "addChatMessage", parameters: ["message": message]) as URLRequest
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
