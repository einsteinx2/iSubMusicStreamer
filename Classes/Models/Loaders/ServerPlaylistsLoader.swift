//
//  ServerPlaylistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class ServerPlaylistsLoader: APILoader {
    @Injected private var store: Store
    
    override var type: APILoaderType { .serverPlaylists }
    
    var serverId = Settings.shared().currentServerId
    var serverPlaylists = [ServerPlaylist]()
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "getPlaylists", parameters: nil) as URLRequest
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
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
