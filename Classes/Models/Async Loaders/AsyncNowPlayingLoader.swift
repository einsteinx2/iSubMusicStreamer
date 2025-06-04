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
        
        guard let root = try await validate(data: data), let nowPlaying = try await validateChild(parent: root, childTag: "nowPlaying") else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()
        
        var nowPlayingSongs = [NowPlayingSong]()
        for try await element in nowPlaying.iterate("entry") {
            let song = Song(serverId: self.serverId, element: element)
            guard store.add(song: song) else {
                throw APIError.database
            }
            nowPlayingSongs.append(NowPlayingSong(serverId: serverId, element: element))
        }
        
        return nowPlayingSongs
    }
}
