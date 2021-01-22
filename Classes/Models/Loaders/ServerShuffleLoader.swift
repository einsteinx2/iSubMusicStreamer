//
//  ServerShuffleLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class ServerShuffleLoader: AbstractAPILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int?
    
    init(serverId: Int, mediaFolderId: Int? = nil, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .serverShuffle }
    
    override func createRequest() -> URLRequest? {
        // Start the 100 record open search to create shuffle list
        var parameters: [String: Any] = ["size": "100"]
        if let mediaFolderId = mediaFolderId, mediaFolderId != MediaFolder.allFoldersId {
            parameters["musicFolderId"] = "\(mediaFolderId)"
        }
        return URLRequest(serverId: serverId, subsonicAction: "getRandomSongs", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        let parser = SearchXMLParser(serverId: serverId, data: data)
        _ = store.playSong(position: 0, songs: parser.songs)
        informDelegateLoadingFinished()
    }
}
