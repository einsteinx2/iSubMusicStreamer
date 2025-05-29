//
//  ServerPlaylistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class ServerPlaylistLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let serverPlaylistId: Int
    
    convenience init(serverPlaylist: ServerPlaylist, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.init(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, delegate: delegate, callback: callback)
    }
    
    init(serverId: Int, serverPlaylistId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.serverPlaylistId = serverPlaylistId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverPlaylist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getPlaylist, parameters: ["id": serverPlaylistId])
    }
    
    override func processResponse(data: Data) {
        guard let root = validate(data: data) else { return }
        guard let playlist = validateChild(parent: root, childTag: "playlist") else { return }
        guard store.clear(serverId: serverId, serverPlaylistId: serverPlaylistId) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        playlist.iterate("entry") { e, stop in
            let song = Song(serverId: self.serverId, element: e)
            guard self.store.add(song: song) && self.store.add(song: song, serverId: self.serverId, serverPlaylistId: self.serverPlaylistId) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop = true
                return
            }
        }
        
        informDelegateLoadingFinished()
    }
}
