//
//  MediaFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class MediaFoldersLoader: APILoader {
    let serverId: Int
    
    private(set) var mediaFolders = [MediaFolder]()
    
    init(serverId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .mediaFolders }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getMusicFolders")
    }
    
    override func processResponse(data: Data) {
        self.mediaFolders = []
        guard let root = validate(data: data) else { return }
        guard let musicFolders = validateChild(parent: root, childTag: "musicFolders") else { return }
        
        var mediaFolders = [MediaFolder(serverId: serverId, id: MediaFolder.allFoldersId, name: "All Media Folders")]
        musicFolders.iterate("musicFolder") { e, _ in
            mediaFolders.append(MediaFolder(serverId: self.serverId, element: e))
        }
        
        self.mediaFolders = mediaFolders
        informDelegateLoadingFinished()
    }
}
