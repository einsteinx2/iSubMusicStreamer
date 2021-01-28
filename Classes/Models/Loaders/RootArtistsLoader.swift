//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootArtistsLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int
    
    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var tagArtistIds = [Int]()
    
    init(serverId: Int, mediaFolderId: Int, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .rootArtists }
        
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any]? = mediaFolderId != MediaFolder.allFoldersId ? ["musicFolderId": mediaFolderId] : nil
        return URLRequest(serverId: serverId, subsonicAction: "getArtists", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        metadata = nil
        tableSections.removeAll()
        tagArtistIds.removeAll()
        guard let root = validate(data: data) else { return }
        guard let artists = validateChild(parent: root, childTag: "artists") else { return }
        guard store.deleteTagArtists(serverId: serverId, mediaFolderId: mediaFolderId) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        var rowCount = 0
        var sectionCount = 0
        var rowIndex = 0
        let success = artists.iterate("index") { e, stop in
            sectionCount = 0
            rowIndex = rowCount
            let success = e.iterate("artist") { artist, bool in
                // Add the artist to the DB
                let tagArtist = TagArtist(serverId: self.serverId, element: artist)
                guard self.store.add(tagArtist: tagArtist, mediaFolderId: self.mediaFolderId) else {
                    self.informDelegateLoadingFailed(error: APIError.database)
                    stop.pointee = true
                    return
                }
                self.tagArtistIds.append(tagArtist.id)
                rowCount += 1
                sectionCount += 1
            }
            guard success else { return }
            
            let section = TableSection(serverId: self.serverId,
                                       mediaFolderId: self.mediaFolderId,
                                       name: e.attribute("name").stringXML,
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard self.store.add(tagArtistSection: section) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop.pointee = true
                return
            }
            self.tableSections.append(section)
        }
        guard success else { return }
        
        // Update the metadata
        let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
        guard store.add(tagArtistListMetadata: metadata) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        self.metadata = metadata
        informDelegateLoadingFinished()
    }
}
