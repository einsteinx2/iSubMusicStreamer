//
//  AsyncServerShuffleLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class AsyncServerShuffleLoader: AsyncAPILoader<[Song]> {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int?
    
    init(serverId: Int, mediaFolderId: Int? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverShuffle }
    
    override func createRequest() -> URLRequest? {
        // Start the 100 record open search to create shuffle list
        var parameters: [String: Any] = ["size": 100]
        if let mediaFolderId = mediaFolderId, mediaFolderId != MediaFolder.allFoldersId {
            parameters["musicFolderId"] = mediaFolderId
        }
        return URLRequest(serverId: serverId, subsonicAction: .getRandomSongs, parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> [Song] {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data) else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()
                
        var songs = [Song]()
        for try await element in root.iterate("randomSongs.song") {
            let song = Song(serverId: serverId, element: element)
            guard self.store.add(song: song) else {
                throw APIError.database
            }
            songs.append(song)
        }
        
        return songs
    }
}
