//
//  RecursiveSongLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc final class RecursiveSongLoader: NSObject {
    var callback: LoaderCallback?
        
    private var subfolderLoader: SubfolderLoader?
    private var tagArtistLoader: TagArtistLoader?
    private var tagAlbumLoader: TagAlbumLoader?
    
    private var isQueue = false
    private var isDownload = false
    private var isLoading = false
    private var isCancelled = false
    
    private var folderIds = [String]()
    private var artistIds = [String]()
    
    @objc init(folderId: String, callback: LoaderCallback?) {
        self.folderIds.append(folderId)
        self.callback = callback
        super.init()
    }
    
    @objc init(tagArtistId: String, callback: LoaderCallback?) {
        self.artistIds.append(tagArtistId)
        self.callback = callback
        super.init()
    }
    
    @objc func queueAll() {
        guard !isLoading else { return }
        
        isQueue = true
        isDownload = false
        isCancelled = false
        startLoad()
    }
    
    @objc func downloadAll() {
        guard !isLoading else { return }
        
        isQueue = false
        isDownload = true
        isCancelled = false
        startLoad()
    }
    
    @objc func cancelLoad() {
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
        } else if artistIds.count > 0 {
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
        
        subfolderLoader = SubfolderLoader(folderId: folderId, callback: { [unowned self] success, error in
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
        guard !isCancelled, let artistId = artistIds.first else {
            finishLoad()
            return
        }
        
        artistIds.remove(at: 0)
        
        tagArtistLoader = TagArtistLoader(artistId: artistId) { [unowned self] success, error in
            if success {
                if let tagAlbums = self.tagArtistLoader?.tagAlbums {
                    self.tagArtistLoader = nil
                    self.loadAlbums(tagAlbums: tagAlbums)
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
    
    private func loadAlbums(tagAlbums: [TagAlbum]) {
        tagAlbums.forEach { tagAlbum in
            tagAlbumLoader = TagAlbumLoader(albumId: tagAlbum.id) { [unowned self] success, error in
                if success {
                    if let songs = self.tagAlbumLoader?.songs {
                        self.tagAlbumLoader = nil
                        songs.forEach { self.handleSong(song: $0) }
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
            song.addToCurrentPlaylistDbQueue()
        } else if isDownload {
            song.addToCacheQueueDbQueue()
        }
    }
    
    private func loadingFailed(success: Bool, error: Error?) {
        cleanup()
        isLoading = false
        self.callback?(success, error)
    }
    
    private func finishLoad() {
        if isQueue {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
            
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
//                StreamManager.shared().fillStreamQueue(AudioEngine.shared().player?.isStarted ?? false)
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
