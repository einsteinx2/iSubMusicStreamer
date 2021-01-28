//
//  NowPlayingLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class NowPlayingLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    
    private(set) var nowPlayingSongs = [NowPlayingSong]()
    
    init(serverId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .nowPlaying }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getNowPlaying")
    }
    
    override func processResponse(data: Data) {
        nowPlayingSongs.removeAll()
        guard let root = validate(data: data) else { return }
        guard let nowPlaying = validateChild(parent: root, childTag: "nowPlaying") else { return }
        
        let success = nowPlaying.iterate("entry") { e, stop in
            let song = Song(serverId: self.serverId, element: e)
            guard self.store.add(song: song) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop.pointee = true
                return
            }
            self.nowPlayingSongs.append(NowPlayingSong(serverId: self.serverId, element: e))
        }
        guard success else { return }
        
        informDelegateLoadingFinished()
    }
}
