//
//  AsyncTagAlbumLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class AsyncTagAlbumLoader: AsyncAPILoader<[String]> {
    @Injected private var store: Store

    let serverId: Int
    let tagAlbumId: String
    
    private(set) var songIds = [String]()
    
    init(serverId: Int, tagAlbumId: String) {
        self.serverId = serverId
        self.tagAlbumId = tagAlbumId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagAlbum }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getAlbum, parameters: ["id": tagAlbumId])
    }
    
    override func processResponse(data: Data) async throws -> [String] {
        try Task.checkCancellation()
        
        let album = try require(decodeSubsonicResponse(data: data).album, "album")
        guard store.deleteTagSongs(serverId: serverId, tagAlbumId: tagAlbumId) else {
            throw APIError.database
        }

        try Task.checkCancellation()

        let tagAlbum = TagAlbum(serverId: serverId, dto: album)
        guard store.add(tagAlbum: tagAlbum) else {
            throw APIError.database
        }

        try Task.checkCancellation()

        var songIds = [String]()
        for dto in album.song?.values ?? [] {
            let song = Song(serverId: serverId, dto: dto)
            let isVideoSupported = store.server(id: serverId)?.isVideoSupported ?? false
            if song.path != "" && (isVideoSupported || !song.isVideo) {
                // Fix for pdfs showing in directory listing
                // TODO: See if this is still necessary
                if song.suffix.lowercased() != "pdf" {
                    guard store.add(tagSong: song) else {
                        throw APIError.database
                    }
                    songIds.append(song.id)
                }
            }
        }
        
        return songIds
    }
}
