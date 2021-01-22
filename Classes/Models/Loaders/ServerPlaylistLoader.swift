//
//  ServerPlaylistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class ServerPlaylistLoader: AbstractAPILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let serverPlaylistId: Int
    
    convenience init(serverPlaylist: ServerPlaylist, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.init(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, delegate: delegate, callback: callback)
    }
    
    init(serverId: Int, serverPlaylistId: Int, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.serverPlaylistId = serverPlaylistId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverPlaylist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getPlaylist", parameters: ["id": serverPlaylistId])
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                guard store.clear(serverId: serverId, serverPlaylistId: serverPlaylistId) else {
                    informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
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
