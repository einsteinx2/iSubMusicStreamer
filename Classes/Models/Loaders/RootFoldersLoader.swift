//
//  RootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootFoldersLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int
    
    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var folderArtistIds = [Int]()
    
    init(serverId: Int, mediaFolderId: Int, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .rootArtists }
        
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any]? = mediaFolderId != MediaFolder.allFoldersId ? ["musicFolderId": mediaFolderId] : nil
        return URLRequest(serverId: serverId, subsonicAction: "getIndexes", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        metadata = nil
        tableSections.removeAll()
        folderArtistIds.removeAll()
        guard let root = validate(data: data) else { return }
        guard let indexes = validateChild(parent: root, childTag: "indexes") else { return }
        guard store.deleteFolderArtists(serverId: serverId, mediaFolderId: mediaFolderId) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        // Process shortcuts (basically just custom folder artists)
        var rowCount = 0
        var sectionCount = 0
        var rowIndex = 0
        var success = indexes.iterate("shortcut") { e, stop in
            let shortcut = FolderArtist(serverId: self.serverId, element: e)
            guard self.store.add(folderArtist: shortcut, mediaFolderId: self.mediaFolderId) else {
                self.informDelegateLoadingFailed(error: APIError.database)
                stop.pointee = true
                return
            }
            self.folderArtistIds.append(shortcut.id)
            rowCount += 1
            sectionCount += 1
        }
        guard success else { return }
        
        if sectionCount > 0 {
            let section = TableSection(serverId: self.serverId,
                                       mediaFolderId: self.mediaFolderId,
                                       name: "*",
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard store.add(folderArtistSection: section) else {
                informDelegateLoadingFailed(error: APIError.database)
                return
            }
            self.tableSections.append(section)
        }
        
        // Process folder artists
        success = indexes.iterate("index") { e, stop in
            sectionCount = 0
            rowIndex = rowCount
            let success = e.iterate("artist") { artist, stop in
                // Add the artist to the DB
                let folderArtist = FolderArtist(serverId: self.serverId, element: artist)
                // Prevent inserting .AppleDouble folders
                if folderArtist.name != ".AppleDouble" {
                    guard self.store.add(folderArtist: folderArtist, mediaFolderId: self.mediaFolderId) else {
                        self.informDelegateLoadingFailed(error: APIError.database)
                        stop.pointee = true
                        return
                    }
                    self.folderArtistIds.append(folderArtist.id)
                    rowCount += 1
                    sectionCount += 1
                }
            }
            guard success else {
                stop.pointee = true
                return
            }
            
            let section = TableSection(serverId: self.serverId,
                                       mediaFolderId: self.mediaFolderId,
                                       name: e.attribute("name").stringXML,
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard self.store.add(folderArtistSection: section) else {
                stop.pointee = true
                return
            }
            self.tableSections.append(section)
        }
        guard success else { return }
        
        // Update the metadata
        let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
        guard store.add(folderArtistListMetadata: metadata) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        self.metadata = metadata
        informDelegateLoadingFinished()
    }
}
