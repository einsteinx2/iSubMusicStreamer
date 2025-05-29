//
//  SongLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class SongLoader: APILoader {
    @Injected private var store: Store

    let serverId: Int
    let songId: String
    
    private(set) var song: Song?
    
    init(serverId: Int, songId: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.songId = songId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .song }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getSong, parameters: ["id": songId])
    }
    
    override func processResponse(data: Data) {
        song = nil
        guard let root = validate(data: data) else { return }
        guard let songElement = validateChild(parent: root, childTag: "song") else { return }
        
        let song = Song(serverId: serverId, element: songElement)
        guard store.add(song: song) else {
            self.informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        self.song = song
        informDelegateLoadingFinished()
    }
}
