//
//  TagArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class TagArtistLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let tagArtistId: String
    
    private(set) var tagAlbumIds = [String]()
    
    init(serverId: Int, tagArtistId: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.tagArtistId = tagArtistId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagArtist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getArtist", parameters: ["id": tagArtistId])
    }
    
    override func processResponse(data: Data) {
        tagAlbumIds.removeAll()
        guard let root = validate(data: data) else { return }
        guard let artist = validateChild(parent: root, childTag: "artist") else { return }
        guard store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) else  {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
            
        let tagArtist = TagArtist(serverId: serverId, element: artist)
        guard self.store.add(tagArtist: tagArtist, mediaFolderId: MediaFolder.allFoldersId) else {
            self.informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        let success = artist.iterate("album") { element, stop in
            let tagAlbum = TagAlbum(serverId: self.serverId, element: element)
            guard self.store.add(tagAlbum: tagAlbum) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop.pointee = true
                return
            }
            self.tagAlbumIds.append(tagAlbum.id)
        }
        guard success else { return }
        
        informDelegateLoadingFinished()
    }
}
