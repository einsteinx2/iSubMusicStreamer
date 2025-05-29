//
//  AsyncTagArtistLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/29/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Resolver

final class AsyncTagArtistLoader: AsyncAPILoader<[String]> {
    @Injected private var store: Store
    
    let serverId: Int
    let tagArtistId: String
    
    init(serverId: Int, tagArtistId: String) {
        self.serverId = serverId
        self.tagArtistId = tagArtistId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagArtist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getArtist, parameters: ["id": tagArtistId])
    }
    
    override func processResponse(data: Data) async throws -> [String] {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let artist = try await validateChild(parent: root, childTag: "artist") else {
            return []
        }
        guard store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) else  {
            throw APIError.database
        }
        
        try Task.checkCancellation()
            
        let tagArtist = TagArtist(serverId: serverId, element: artist)
        guard self.store.add(tagArtist: tagArtist, mediaFolderId: MediaFolder.allFoldersId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        var tagAlbumIds = [String]()
        for try await element in artist.iterate("album") {
            let tagAlbum = TagAlbum(serverId: self.serverId, element: element)
            guard self.store.add(tagAlbum: tagAlbum) else {
                throw APIError.database
            }
            tagAlbumIds.append(tagAlbum.id)
        }
        
        return tagAlbumIds
    }
}
