//
//  SubFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

typealias FolderAlbumHandler = (_ folderAlbum: FolderAlbum) -> ()
typealias SongHandler = (_ song: Song) -> ()

final class SubfolderLoader: APILoader {
    @Injected private var store: Store
    
    override var type: APILoaderType { .subFolders }
    
    let serverId: Int
    let parentFolderId: String
    
    private(set) var folderMetadata: FolderMetadata?
    private(set) var folderAlbumIds = [String]()
    private(set) var songIds = [String]()
    
    var onProcessFolderAlbum: FolderAlbumHandler?
    var onProcessSong: SongHandler?
    
    init(serverId: Int, parentFolderId: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil, folderAlbumHandler: FolderAlbumHandler? = nil, songHandler: SongHandler? = nil) {
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        self.onProcessFolderAlbum = folderAlbumHandler
        self.onProcessSong = songHandler
        super.init(delegate: delegate, callback: callback)
    }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getMusicDirectory, parameters: ["id": parentFolderId])
    }
    
    override func processResponse(data: Data) {
        folderMetadata = nil
        folderAlbumIds.removeAll()
        songIds.removeAll()
        guard let root = validate(data: data) else { return }
        guard let directory = validateChild(parent: root, childTag: "directory") else { return }
        guard store.resetFolderAlbumCache(serverId: serverId, parentFolderId: parentFolderId) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        var songCount = 0
        var duration = 0
        var folderAlbums = [FolderAlbum]()
        let success = directory.iterate("child") { element, stop in
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
                            self.informDelegateLoadingFailed(error: APIError.database)
                            stop = true
                            return
                        }
                        
                        self.songIds.append(song.id)
                        songCount += 1
                        duration += song.duration
                        
                        // Optionally the client can do something with the song object
                        self.onProcessSong?(song)
                    }
                }
            }
        }
        guard success else { return }
        
        // Hack for Subsonic 4.7 breaking alphabetical order
        folderAlbums.sort { $0.name.caseInsensitiveCompare($1.name) != .orderedDescending }
        var folderCount = 0
        for folderAlbum in folderAlbums {
            guard store.add(folderAlbum: folderAlbum) else {
                informDelegateLoadingFailed(error: APIError.database)
                return
            }
            self.folderAlbumIds.append(folderAlbum.id)
            folderCount += 1
        }
        
        let metadata = FolderMetadata(serverId: serverId, parentFolderId: parentFolderId, folderCount: folderCount, songCount: songCount, duration: duration)
        guard store.add(folderMetadata: metadata) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        folderMetadata = metadata
        informDelegateLoadingFinished()
    }
}
