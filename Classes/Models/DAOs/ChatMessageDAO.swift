//
//  ChatMessageDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ChatMessageDAO: NSObject {
    @objc var serverId = Settings.shared().currentServerId
    
    private var loader: ChatLoader?
    private var dataTask: URLSessionDataTask?
    @objc weak var delegate: SUSLoaderDelegate?
    
    @objc var chatMessages = [ChatMessage]()
    
    @objc init(delegate: SUSLoaderDelegate?) {
        self.delegate = delegate
        super.init()
    }
    
    deinit {
        loader?.cancelLoad()
        loader?.delegate = nil
        dataTask?.cancel()
    }
    
    @objc func send(message: String) {
        let request = NSMutableURLRequest(susAction: "addChatMessage", parameters: ["message": message]) as URLRequest
        dataTask = SUSLoader.sharedSession().dataTask(with: request) { [weak self] data, response, error in
            EX2Dispatch.runInMainThreadAsync {
                if error != nil {
                    self?.delegate?.loadingFailed(nil, withError: NSError(ismsCode: Int(ISMSErrorCode_CouldNotSendChatMessage), extraAttributes: ["message": message]))
                } else {
                    self?.startLoad()
                }
            }
        }
    }
}

@objc extension ChatMessageDAO: SUSLoaderManager {
    func startLoad() {
        cancelLoad()
        loader = ChatLoader(delegate: self)
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension ChatMessageDAO: SUSLoaderDelegate {
    func loadingFinished(_ loader: SUSLoader?) {
        if let loader = loader as? ChatLoader {
            chatMessages = loader.chatMessages
        }
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(nil)
    }
    
    func loadingFailed(_ loader: SUSLoader?, withError error: Error?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(nil, withError: error)
    }
}
