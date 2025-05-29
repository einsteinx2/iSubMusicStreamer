//
//  AsyncRootArtistsLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/28/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Resolver

final class AsyncRootArtistsLoader: AsyncAPILoader<ArtistsAPIResponseData?> {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int
    
    init(serverId: Int, mediaFolderId: Int) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .rootArtists }
        
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any]? = mediaFolderId != MediaFolder.allFoldersId ? ["musicFolderId": mediaFolderId] : nil
        return URLRequest(serverId: serverId, subsonicAction: "getArtists", parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> ArtistsAPIResponseData? {
        try Task.checkCancellation()
        
        var responseData = ArtistsAPIResponseData()
        
        guard let root = try await validate(data: data), let artists = try await validateChild(parent: root, childTag: "artists") else {
            return nil
        }
        guard store.deleteTagArtists(serverId: serverId, mediaFolderId: mediaFolderId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        var rowCount = 0
        var sectionCount = 0
        var rowIndex = 0
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            let internalSuccess = artists.iterate("index") { e, stop in
                sectionCount = 0
                rowIndex = rowCount
                let success = e.iterate("artist") { artist, bool in
                    // Add the artist to the DB
                    let tagArtist = TagArtist(serverId: self.serverId, element: artist)
                    guard self.store.add(tagArtist: tagArtist, mediaFolderId: self.mediaFolderId) else {
                        stop = true
                        continuation.resume(throwing: APIError.database)
                        return
                    }
                    responseData.artistIds.append(tagArtist.id)
                    rowCount += 1
                    sectionCount += 1
                }
                guard success else {
                    stop = true
                    return
                }
                
                let section = TableSection(serverId: self.serverId,
                                           mediaFolderId: self.mediaFolderId,
                                           name: e.attribute("name").stringXML,
                                           position: rowIndex,
                                           itemCount: sectionCount)
                guard self.store.add(tagArtistSection: section) else {
                    stop = true
                    continuation.resume(throwing: APIError.database)
                    return
                }
                responseData.tableSections.append(section)
            }
            continuation.resume(returning: internalSuccess)
        }
        guard success else {
            return nil
        }
        
        try Task.checkCancellation()
        
        // Update the metadata
        let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
        guard store.add(tagArtistListMetadata: metadata) else {
            throw APIError.database
        }
                
        responseData.metadata = metadata
        return responseData
    }
}
