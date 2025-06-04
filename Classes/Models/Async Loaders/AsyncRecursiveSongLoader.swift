//
//  AsyncRecursiveSongLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

enum RecursiveSongLoaderIdType {
    case folder
    case tagArtist
}

enum RecursiveSongLoaderAction {
    case downloadAll
    case playAll
    case queueAll
    case queueAllNext
    case shuffleAll
}

struct AsyncRecursiveSongLoader {
    static func load(serverId: Int, id: String, idType: RecursiveSongLoaderIdType, action: RecursiveSongLoaderAction) async throws {
        switch idType {
        case .folder:
            try await loadNextFolder(serverId: serverId, folderIds: [id], action: action)
        case .tagArtist:
            try await loadNextTagArtist(serverId: serverId, tagArtistIds: [id], action: action)
        }
    }
    
    private static func loadNextFolder(serverId: Int, folderIds: [String], action: RecursiveSongLoaderAction) async throws {
        print("folderIds: \(folderIds)")
        var folderIds = Array(folderIds.reversed())
        print("folderIds reversed: \(folderIds)")
        var queueNextOffset = 0
        
        while let folderId = folderIds.popLast() {
            try Task.checkCancellation()
            
            let responseData = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: folderId).load()
            
            try Task.checkCancellation()
            
            folderIds.append(contentsOf: Array(responseData.folderAlbumIds.reversed()))
            handleSongIds(serverId: serverId, songIds: responseData.songIds, action: action, queueNextOffset: &queueNextOffset)
        }
    }
    
    private static func loadNextTagArtist(serverId: Int, tagArtistIds: [String], action: RecursiveSongLoaderAction) async throws {
        var tagArtistIds = Array(tagArtistIds.reversed())
        var queueNextOffset = 0
        
        while let tagArtistId = tagArtistIds.popLast() {
            try Task.checkCancellation()
            
            let tagAlbumIds = try await AsyncTagArtistLoader(serverId: serverId, tagArtistId: tagArtistId).load()
            
            try Task.checkCancellation()
            
            try await loadTagAlbums(serverId: serverId, tagAlbumIds: tagAlbumIds, action: action, queueNextOffset: &queueNextOffset)
        }
    }
    
    private static func loadTagAlbums(serverId: Int, tagAlbumIds: [String], action: RecursiveSongLoaderAction, queueNextOffset: inout Int) async throws {
        var tagAlbumIds = Array(tagAlbumIds.reversed())
        
        while let tagAlbumId = tagAlbumIds.popLast() {
            try Task.checkCancellation()
            
            let songIds = try await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId).load()
            
            try Task.checkCancellation()
            
            handleSongIds(serverId: serverId, songIds: songIds, action: action, queueNextOffset: &queueNextOffset)
        }
    }
    
    private static func handleSongIds(serverId: Int, songIds: [String], action: RecursiveSongLoaderAction, queueNextOffset: inout Int) {
        let store: Store = Resolver.resolve()
        switch action {
        case .downloadAll:
            _ = store.addToDownloadQueue(serverId: serverId, songIds: songIds)
        case .queueAll, .playAll, .shuffleAll:
            _ = store.queue(songIds: songIds, serverId: serverId)
        case .queueAllNext:
            for songId in songIds {
                if let song = store.song(serverId: serverId, id: songId) {
                    song.queueNext(offset: queueNextOffset)
                    queueNextOffset += 1
                }
            }
        }
    }
}
