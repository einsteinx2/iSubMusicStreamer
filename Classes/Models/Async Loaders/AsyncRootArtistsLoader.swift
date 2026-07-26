//
//  AsyncRootArtistsLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/28/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Resolver

final class AsyncRootArtistsLoader: AsyncAPILoader<ArtistsAPIResponseData> {
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
        return URLRequest(serverId: serverId, subsonicAction: .getArtists, parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> ArtistsAPIResponseData {
        try Task.checkCancellation()
        
        var tableSections = [TableSection]()
        var artistIds = [String]()
        
        let artists = try require(decodeSubsonicResponse(data: data).artists, "artists")
        guard store.deleteTagArtists(serverId: serverId, mediaFolderId: mediaFolderId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        var rowCount = 0
        var sectionCount = 0
        var rowIndex = 0
        
        for index in artists.index?.values ?? [] {
            sectionCount = 0
            rowIndex = rowCount
            for dto in index.artist?.values ?? [] {
                // Add the artist to the DB
                let tagArtist = TagArtist(serverId: serverId, dto: dto)
                guard store.add(tagArtist: tagArtist, mediaFolderId: mediaFolderId) else {
                    throw APIError.database
                }
                artistIds.append(tagArtist.id)
                rowCount += 1
                sectionCount += 1
            }
            
            let section = TableSection(serverId: serverId,
                                       mediaFolderId: mediaFolderId,
                                       name: index.name ?? "nil",
                                       position: rowIndex,
                                       itemCount: sectionCount)
            guard store.add(tagArtistSection: section) else {
                throw APIError.database
            }
            tableSections.append(section)
        }
        
        try Task.checkCancellation()
        
        // Update the metadata
        let metadata = RootListMetadata(serverId: serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
        guard store.add(tagArtistListMetadata: metadata) else {
            throw APIError.database
        }
                
        return ArtistsAPIResponseData(metadata: metadata, tableSections: tableSections, artistIds: artistIds)
    }
}
