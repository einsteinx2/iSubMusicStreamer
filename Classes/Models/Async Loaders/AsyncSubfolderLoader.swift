//
//  AsyncSubfolderLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/29/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Resolver

struct SubfolderAPIResponseData {
    let folderMetadata: FolderMetadata?
    let folderAlbumIds: [String]
    let songIds: [String]
}

final class AsyncSubfolderLoader: AsyncAPILoader<SubfolderAPIResponseData?> {
    @Injected private var store: Store
    
    override var type: APILoaderType { .subFolders }
    
    let serverId: Int
    let parentFolderId: String
    
    var onProcessFolderAlbum: FolderAlbumHandler?
    var onProcessSong: SongHandler?
    
    init(serverId: Int, parentFolderId: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil, folderAlbumHandler: FolderAlbumHandler? = nil, songHandler: SongHandler? = nil) {
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        self.onProcessFolderAlbum = folderAlbumHandler
        self.onProcessSong = songHandler
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getMusicDirectory", parameters: ["id": parentFolderId])
    }
    
    override func processResponse(data: Data) async throws -> SubfolderAPIResponseData? {
        try Task.checkCancellation()
        
        var folderAlbumIds = [String]()
        var songIds = [String]()
        
        guard let root = try await validate(data: data), let directory = try await validateChild(parent: root, childTag: "directory") else {
            return nil
        }
        guard store.resetFolderAlbumCache(serverId: serverId, parentFolderId: parentFolderId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        var songCount = 0
        var duration = 0
        var folderAlbums = [FolderAlbum]()
        for try await element in directory.iterate("child") {
            if element.attribute("isDir").boolXML {
                let folderAlbum = FolderAlbum(serverId: self.serverId, element: element)
                if folderAlbum.name != ".AppleDouble" {
                    folderAlbums.append(folderAlbum)
                    
                    // Optionally the client can do something with the folder album object
                    self.onProcessFolderAlbum?(folderAlbum)
                }
            } else {
                let song = Song(serverId: self.serverId, element: element)
                let isVideoSupported = self.store.server(id: self.serverId)?.isVideoSupported ?? false
                if song.path != "" && (isVideoSupported || !song.isVideo) {
                    // Fix for pdfs showing in directory listing
                    // TODO: See if this is still necessary
                    if song.suffix.lowercased() != "pdf" {
                        guard self.store.add(folderSong: song) else {
                            throw APIError.database
                        }
                        
                        songIds.append(song.id)
                        songCount += 1
                        duration += song.duration
                        
                        // Optionally the client can do something with the song object
                        self.onProcessSong?(song)
                    }
                }
            }
        }
        
        try Task.checkCancellation()
        
        // Hack for Subsonic 4.7 breaking alphabetical order
        folderAlbums.sort { $0.name.caseInsensitiveCompare($1.name) != .orderedDescending }
        var folderCount = 0
        for folderAlbum in folderAlbums {
            guard store.add(folderAlbum: folderAlbum) else {
                throw APIError.database
            }
            folderAlbumIds.append(folderAlbum.id)
            folderCount += 1
        }
        
        try Task.checkCancellation()
        
        let metadata = FolderMetadata(serverId: serverId, parentFolderId: parentFolderId, folderCount: folderCount, songCount: songCount, duration: duration)
        guard store.add(folderMetadata: metadata) else {
            throw APIError.database
        }
        
        return SubfolderAPIResponseData(folderMetadata: metadata, folderAlbumIds: folderAlbumIds, songIds: songIds)
    }
}
