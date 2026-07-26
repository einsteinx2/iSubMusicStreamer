//
//  AsyncServerPlaylistsLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class AsyncServerPlaylistsLoader: AsyncAPILoader<[ServerPlaylist]> {
    @Injected private var store: Store
    
    let serverId: Int
        
    init(serverId: Int) {
        self.serverId = serverId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverPlaylists }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getPlaylists)
    }
    
    override func processResponse(data: Data) async throws -> [ServerPlaylist] {
        try Task.checkCancellation()
        
        let playlists = try require(decodeSubsonicResponse(data: data).playlists, "playlists")

        try Task.checkCancellation()

        var serverPlaylists = [ServerPlaylist]()
        for dto in playlists.playlist?.values ?? [] {
            let serverPlaylist = ServerPlaylist(serverId: self.serverId, dto: dto)
            guard self.store.add(serverPlaylist: serverPlaylist) else {
                throw APIError.database
            }
            serverPlaylists.append(serverPlaylist)
        }
        
        return serverPlaylists
    }
}
