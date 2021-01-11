//
//  ServerPlaylistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class ServerPlaylistsLoader: SUSLoader {
    @Injected private var store: Store
    
    override var type: SUSLoaderType { SUSLoaderType_ServerPlaylists }
    
    @objc var serverId = Settings.shared().currentServerId
    @objc var serverPlaylists = [ServerPlaylist]()
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "getPlaylists", parameters: nil) as URLRequest
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
                serverPlaylists.removeAll()
                root.iterate("playlists.playlist") { e in
                    let serverPlaylist = ServerPlaylist(serverId: self.serverId, element: e)
                    if self.store.add(serverPlaylist: serverPlaylist) {
                        self.serverPlaylists.append(serverPlaylist)
                    }
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
