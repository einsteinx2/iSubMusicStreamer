//
//  AsyncSongLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class AsyncSongLoader: AsyncAPILoader<Song> {
    @Injected private var store: Store

    let serverId: Int
    let songId: String
        
    init(serverId: Int, songId: String) {
        self.serverId = serverId
        self.songId = songId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .song }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getSong, parameters: ["id": songId])
    }
    
    override func processResponse(data: Data) async throws -> Song {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let element = try await validateChild(parent: root, childTag: "song") else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()

        let song = Song(serverId: serverId, element: element)
        guard store.add(song: song) else {
            throw APIError.database
        }
        
        return song
    }
}
