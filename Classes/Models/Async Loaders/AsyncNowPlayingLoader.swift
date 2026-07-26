//
//  AsyncNowPlayingLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class AsyncNowPlayingLoader: AsyncAPILoader<[NowPlayingSong]> {
    @Injected private var store: Store
    
    let serverId: Int
        
    init(serverId: Int) {
        self.serverId = serverId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .nowPlaying }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getNowPlaying)
    }
    
    override func processResponse(data: Data) async throws -> [NowPlayingSong] {
        try Task.checkCancellation()
        
        let nowPlaying = try require(decodeSubsonicResponse(data: data).nowPlaying, "nowPlaying")

        try Task.checkCancellation()

        var nowPlayingSongs = [NowPlayingSong]()
        for dto in nowPlaying.entry?.values ?? [] {
            let song = Song(serverId: self.serverId, dto: dto)
            guard store.add(song: song) else {
                throw APIError.database
            }
            nowPlayingSongs.append(NowPlayingSong(serverId: serverId, dto: dto))
        }
        
        return nowPlayingSongs
    }
}
