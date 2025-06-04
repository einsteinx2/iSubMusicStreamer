//
//  AsyncSubfolderLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/29/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Resolver

// TODO: Maybe move these structs inside the classes?
struct SubfolderAPIResponseData {
    let folderMetadata: FolderMetadata?
    let folderAlbumIds: [String]
    let songIds: [String]
}

final class AsyncSubfolderLoader: AsyncAPILoader<SubfolderAPIResponseData> {
    @Injected private var store: Store
    
    override var type: APILoaderType { .subFolders }
    
    let serverId: Int
    let parentFolderId: String
    
    init(serverId: Int, parentFolderId: String) {
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getMusicDirectory, parameters: ["id": parentFolderId])
    }
    
    override func processResponse(data: Data) async throws -> SubfolderAPIResponseData {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let directory = try await validateChild(parent: root, childTag: "directory") else {
            throw APIError.responseNotXML
        }
        guard store.resetFolderAlbumCache(serverId: serverId, parentFolderId: parentFolderId) else {
            throw APIError.database
        }
        
        try Task.checkCancellation()
        
        var folderAlbumIds = [String]()
        var songIds = [String]()
        
        var songCount = 0
        var duration = 0
        var folderAlbums = [FolderAlbum]()
        for try await element in directory.iterate("child") {
            if element.attribute("isDir").boolXML {
                let folderAlbum = FolderAlbum(serverId: serverId, element: element)
                if folderAlbum.name != ".AppleDouble" {
                    folderAlbums.append(folderAlbum)
                }
            } else {
                let song = Song(serverId: serverId, element: element)
                let isVideoSupported = store.server(id: serverId)?.isVideoSupported ?? false
                if song.path != "" && (isVideoSupported || !song.isVideo) {
                    // Fix for pdfs showing in directory listing
                    // TODO: See if this is still necessary
                    if song.suffix.lowercased() != "pdf" {
                        guard store.add(folderSong: song) else {
                            throw APIError.database
                        }
                        
                        songIds.append(song.id)
                        songCount += 1
                        duration += song.duration
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
