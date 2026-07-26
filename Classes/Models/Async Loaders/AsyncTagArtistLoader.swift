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
        
        let artist = try require(decodeSubsonicResponse(data: data).artist, "artist")
        guard store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) else  {
            throw APIError.database
        }

        try Task.checkCancellation()

        let tagArtist = TagArtist(serverId: serverId, dto: artist)
        guard store.add(tagArtist: tagArtist, mediaFolderId: MediaFolder.allFoldersId) else {
            throw APIError.database
        }

        try Task.checkCancellation()

        var tagAlbumIds = [String]()
        for dto in artist.album?.values ?? [] {
            let tagAlbum = TagAlbum(serverId: serverId, dto: dto)
            guard store.add(tagAlbum: tagAlbum) else {
                throw APIError.database
            }
            tagAlbumIds.append(tagAlbum.id)
        }
        
        return tagAlbumIds
    }
}
