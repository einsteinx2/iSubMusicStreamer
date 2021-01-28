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
    
    let serverId: Int
    
    private(set) var serverPlaylists = [ServerPlaylist]()
    
    init(serverId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverPlaylists }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getPlaylists")
    }
    
    override func processResponse(data: Data) {
        serverPlaylists.removeAll()
        guard let root = validate(data: data) else { return }
        guard let playlists = validateChild(parent: root, childTag: "playlists") else { return }
        
        let success = playlists.iterate("playlist") { e, stop in
            let serverPlaylist = ServerPlaylist(serverId: self.serverId, element: e)
            guard self.store.add(serverPlaylist: serverPlaylist) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop.pointee = true
                return
            }
            self.serverPlaylists.append(serverPlaylist)
        }
        guard success else { return }
        
        informDelegateLoadingFinished()
    }
}
