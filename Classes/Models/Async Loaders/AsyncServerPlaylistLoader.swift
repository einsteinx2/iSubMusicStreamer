//
//  AsyncServerPlaylistLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class AsyncServerPlaylistLoader: AsyncAPILoader<ServerPlaylist> {
    @Injected private var store: Store
    
    let serverId: Int
    let serverPlaylistId: Int
    
    convenience init(serverPlaylist: ServerPlaylist) {
        self.init(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id)
    }
    
    init(serverId: Int, serverPlaylistId: Int) {
        self.serverId = serverId
        self.serverPlaylistId = serverPlaylistId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverPlaylist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getPlaylist, parameters: ["id": serverPlaylistId])
    }
    
    override func processResponse(data: Data) async throws -> ServerPlaylist {
        try Task.checkCancellation()
        
        let playlist = try require(decodeSubsonicResponse(data: data).playlist, "playlist")

        try Task.checkCancellation()

        guard store.clear(serverId: serverId, serverPlaylistId: serverPlaylistId) else {
            throw APIError.database
        }

        for dto in playlist.entry?.values ?? [] {
            let song = Song(serverId: serverId, dto: dto)
            guard store.add(song: song) && store.add(song: song, serverId: serverId, serverPlaylistId: serverPlaylistId) else {
                throw APIError.database
            }
        }
        
        try Task.checkCancellation()
        
        guard let serverPlaylist = store.serverPlaylist(serverId: serverId, id: serverPlaylistId) else {
            throw APIError.database
        }
        
        return serverPlaylist
    }
}
