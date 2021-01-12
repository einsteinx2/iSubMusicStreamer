//
//  ServerShuffleLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class ServerShuffleLoader: APILoader {
    @Injected private var store: Store
    
    override var type: APILoaderType { .serverShuffle }
    
    var mediaFolderId: Int?
    
    override func createRequest() -> URLRequest? {
        // Start the 100 record open search to create shuffle list
        var parameters = ["size": "100"]
        if let mediaFolderId = mediaFolderId, mediaFolderId != MediaFolder.allFoldersId {
            parameters["musicFolderId"] = "\(mediaFolderId)"
        }
        return NSMutableURLRequest(susAction: "getRandomSongs", parameters: parameters) as URLRequest
    }
    
    override func processResponse(data: Data) {
        let parser = SearchXMLParser(data: data)
        _ = store.playSong(position: 0, songs: parser.songs)
        informDelegateLoadingFinished()
    }
}
