//
//  ServerPlaylistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class ServerPlaylistLoader: SUSLoader {
    @Injected private var store: Store
    
    override var type: SUSLoaderType { SUSLoaderType_ServerPlaylist }
    
    @objc var serverId = Settings.shared().currentServerId
    @objc let serverPlaylistId: Int
    
    @objc init(serverPlaylistId: Int) {
        self.serverPlaylistId = serverPlaylistId
        super.init(delegate: nil)
    }
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "getPlaylist", parameters: ["id": serverPlaylistId]) as URLRequest
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
                guard store.clear(serverId: serverId, serverPlaylistId: serverPlaylistId) else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                    return
                }
                
                root.iterate("playlist.entry") { e in
                    let song = Song(serverId: self.serverId, element: e)
                    if self.store.add(song: song) {
                        _ = self.store.add(song: song, serverId: self.serverId, serverPlaylistId: self.serverPlaylistId)
                    }
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
