//
//  TagAlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class TagAlbumLoader: APILoader {
    @Injected private var store: Store

    let serverId: Int
    let tagAlbumId: String
    
    private(set) var songIds = [String]()
    
    init(serverId: Int, tagAlbumId: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.tagAlbumId = tagAlbumId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagAlbum }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getAlbum, parameters: ["id": tagAlbumId])
    }
    
    override func processResponse(data: Data) {
        songIds.removeAll()
        guard let root = validate(data: data) else { return }
        guard let album = validateChild(parent: root, childTag: "album") else { return }
        guard store.deleteTagSongs(serverId: serverId, tagAlbumId: tagAlbumId) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        let tagAlbum = TagAlbum(serverId: serverId, element: album)
        guard store.add(tagAlbum: tagAlbum) else {
            self.informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        let success = album.iterate("song") { element, stop in
            let song = Song(serverId: self.serverId, element: element)
            let isVideoSupported = self.store.server(id: self.serverId)?.isVideoSupported ?? false
            if song.path != "" && (isVideoSupported || !song.isVideo) {
                // Fix for pdfs showing in directory listing
                // TODO: See if this is still necessary
                if song.suffix.lowercased() != "pdf" {
                    guard self.store.add(tagSong: song) else {
                        self.informDelegateLoadingFailed(error: APIError.database)
                        stop = true
                        return
                    }
                    self.songIds.append(song.id)
                }
            }
        }
        guard success else { return }
        
        informDelegateLoadingFinished()
    }
}
