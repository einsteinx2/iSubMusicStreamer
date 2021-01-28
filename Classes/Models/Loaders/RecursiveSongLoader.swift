//
//  RecursiveSongLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RecursiveSongLoader: CancelableLoader {
    var callback: SuccessErrorCallback?
        
    let serverId: Int
    private var folderIds = [Int]()
    private var tagArtistIds = [Int]()
    
    private var subfolderLoader: SubfolderLoader?
    private var tagArtistLoader: TagArtistLoader?
    private var tagAlbumLoader: TagAlbumLoader?
    
    private var isQueue = false
    private var isDownload = false
    private var isLoading = false
    private var isCancelled = false
    
    init(serverId: Int, folderId: Int, callback: SuccessErrorCallback? = nil) {
        self.serverId = serverId
        self.folderIds.append(folderId)
        self.callback = callback
    }
    
    init(serverId: Int, tagArtistId: Int, callback: SuccessErrorCallback? = nil) {
        self.serverId = serverId
        self.tagArtistIds.append(tagArtistId)
        self.callback = callback
    }
    
    func queueAll() {
        guard !isLoading else { return }
        
        isQueue = true
        isDownload = false
        isCancelled = false
        startLoad()
    }
    
    func downloadAll() {
        guard !isLoading else { return }
        
        isQueue = false
        isDownload = true
        isCancelled = false
        startLoad()
    }
    
    func cancelLoad() {
        guard isLoading && !isCancelled else { return }
        
        cleanup()
        
        isCancelled = true
        isLoading = false
    }
    
    private func startLoad() {
        guard !isLoading else { return }
        
        isLoading = true
        
        if folderIds.count > 0 {
            loadNextFolder()
        } else if tagArtistIds.count > 0 {
            loadNextArtist()
        } else {
            isLoading = false
            isCancelled = true
        }
    }
    
    private func loadNextFolder() {
        guard !isCancelled, let folderId = folderIds.first else {
            finishLoad()
            return
        }
        
        folderIds.remove(at: 0)
        
        subfolderLoader = SubfolderLoader(serverId: serverId, parentFolderId: folderId, callback: { [unowned self] _, success, error in
            if success {
                self.subfolderLoader = nil
                self.loadNextFolder()
            } else {
                self.loadingFailed(success: success, error: error)
            }
        }, folderAlbumHandler: { folderAlbum in
            self.folderIds.append(folderAlbum.id)
        }, songHandler: handleSong)
        subfolderLoader?.startLoad()
    }
    
    private func loadNextArtist() {
        guard !isCancelled, let tagArtistId = tagArtistIds.first else {
            finishLoad()
            return
        }
        
        tagArtistIds.remove(at: 0)
        
        tagArtistLoader = TagArtistLoader(serverId: serverId, tagArtistId: tagArtistId) { [unowned self] _, success, error in
            if success {
                if let tagAlbumIds = self.tagArtistLoader?.tagAlbumIds {
                    self.tagArtistLoader = nil
                    self.loadAlbums(tagAlbumIds: tagAlbumIds)
                    self.loadNextArtist()
                } else {
                    // This should never happen
                    self.loadingFailed(success: success, error: nil)
                }
            } else {
                self.loadingFailed(success: success, error: error)
            }
        }
        tagArtistLoader?.startLoad()
    }
    
    private func loadAlbums(tagAlbumIds: [Int]) {
        tagAlbumIds.forEach { tagAlbumId in
            tagAlbumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { [unowned self] _, success, error in
                if success {
                    if let tagAlbumLoader = self.tagAlbumLoader {
                        self.handleSongIds(songIds: tagAlbumLoader.songIds, serverId: tagAlbumLoader.serverId)
                        self.tagAlbumLoader = nil
                    } else {
                        // This should never happen
                        self.loadingFailed(success: success, error: nil)
                    }
                } else {
                    self.loadingFailed(success: success, error: error)
                }
            }
        }
    }
    
    private func handleSong(song: Song) {
        if isQueue {
            song.queue()
        } else if isDownload {
            song.download()
        }
    }
    
    private func handleSongIds(songIds: [Int], serverId: Int) {
        let store: Store = Resolver.resolve()
        if isQueue {
            _ = store.queue(songIds: songIds, serverId: serverId)
        } else {
            _ = store.addToDownloadQueue(serverId: serverId, songIds: songIds)
        }
    }
    
    private func loadingFailed(success: Bool, error: Error?) {
        cleanup()
        isLoading = false
        self.callback?(success, error)
    }
    
    private func finishLoad() {
        if isQueue {
            NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
            
//            if Settings.shared().isJukeboxEnabled {
//                Jukebox.shared().clearPlaylist()
//            }
//
//            if isShuffle {
//                DatabaseOld.shared().shufflePlaylist()
//            }
//
//            if Settings.shared().isJukeboxEnabled {
//                Jukebox.shared().replacePlaylistWithLocal()
//            } else {
//                StreamManager.shared().fillStreamQueue(player.isStarted)
//            }
        }
        
        self.callback?(true, nil)
    }
    
    private func cleanup() {
        subfolderLoader?.callback = nil
        subfolderLoader?.cancelLoad()
        subfolderLoader = nil
        
        tagArtistLoader?.callback = nil
        tagArtistLoader?.cancelLoad()
        tagAlbumLoader = nil
        
        tagAlbumLoader?.callback = nil
        tagAlbumLoader?.cancelLoad()
        tagAlbumLoader = nil
    }
}
