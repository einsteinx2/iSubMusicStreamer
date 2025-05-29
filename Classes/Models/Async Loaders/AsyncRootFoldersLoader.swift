//
//  AsyncRootFoldersLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/27/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct ArtistsAPIResponseData {
    var metadata: RootListMetadata?
    var tableSections = [TableSection]()
    var artistIds = [String]()
}

final class AsyncRootFoldersLoader: AsyncAPILoader<ArtistsAPIResponseData?> {
    @Injected private var store: Store
    
    override var type: APILoaderType { .rootArtists }
    
    let serverId: Int
    let mediaFolderId: Int
    
    init(serverId: Int, mediaFolderId: Int) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any]? = mediaFolderId != MediaFolder.allFoldersId ? ["musicFolderId": mediaFolderId] : nil
        return URLRequest(serverId: serverId, subsonicAction: "getIndexes", parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> ArtistsAPIResponseData? {
        try Task.checkCancellation()
        
        var responseData = ArtistsAPIResponseData()
        
        guard let root = try await validate(data: data), let indexes = try await validateChild(parent: root, childTag: "indexes") else {
            return nil
        }
        guard store.deleteFolderArtists(serverId: serverId, mediaFolderId: mediaFolderId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        // Process shortcuts (basically just custom folder artists)
        var rowCount = 0
        var sectionCount = 0
        var rowIndex = 0
        
        for try await element in indexes.iterate("shortcut") {
            let shortcut = FolderArtist(serverId: self.serverId, element: element)
            guard self.store.add(folderArtist: shortcut, mediaFolderId: self.mediaFolderId) else {
                throw APIError.database
            }
            responseData.artistIds.append(shortcut.id)
            rowCount += 1
            sectionCount += 1
        }
        
        try Task.checkCancellation()
        
        if sectionCount > 0 {
            let section = TableSection(serverId: self.serverId,
                                       mediaFolderId: self.mediaFolderId,
                                       name: "*",
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard store.add(folderArtistSection: section) else {
                throw APIError.database
            }
            responseData.tableSections.append(section)
        }
        
        try Task.checkCancellation()
        
        // Process folder artists
        for try await element in indexes.iterate("index") {
            sectionCount = 0
            rowIndex = rowCount
            for try await artist in element.iterate("artist") {
                // Add the artist to the DB
                let folderArtist = FolderArtist(serverId: self.serverId, element: artist)
                // Prevent inserting .AppleDouble folders
                if folderArtist.name != ".AppleDouble" {
                    guard self.store.add(folderArtist: folderArtist, mediaFolderId: self.mediaFolderId) else {
                        throw APIError.database
                    }
                    responseData.artistIds.append(folderArtist.id)
                    rowCount += 1
                    sectionCount += 1
                }
            }
            
            try Task.checkCancellation()
            
            let section = TableSection(serverId: self.serverId,
                                       mediaFolderId: self.mediaFolderId,
                                       name: element.attribute("name").stringXML,
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard self.store.add(folderArtistSection: section) else {
                throw APIError.database
            }
            responseData.tableSections.append(section)
        }
        
        try Task.checkCancellation()
        
        // Update the metadata
        let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
        guard store.add(folderArtistListMetadata: metadata) else {
            throw APIError.database
        }
        
        responseData.metadata = metadata
        return responseData
    }
}
