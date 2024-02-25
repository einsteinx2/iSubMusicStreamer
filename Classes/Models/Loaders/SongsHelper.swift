//
//  SongsHelper.swift
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct SongsHelper {
    @Injected private static var store: Store
    @Injected private static var settings: SavedSettings
    @Injected private static var jukebox: Jukebox
    @Injected private static var player: BassPlayer
    @Injected private static var playQueue: PlayQueue
    @Injected private static var streamManager: StreamManager
    
    private static var recursiveLoader: RecursiveSongLoader?
    private static var albumLoader: TagAlbumLoader?
    
    // MARK: Public Helper Functions
    
    static func downloadAll(serverId: Int, folderId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(serverId: Int, tagArtistId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(serverId: Int, tagAlbumId: String) {
        albumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { _, success, error in
            if success, let albumLoader = albumLoader {
                _ = store.addToDownloadQueue(serverId: serverId, songIds: albumLoader.songIds)
            }
            downloadCallback(success: success, error: error)
        }
        albumLoader?.startLoad()
        showLoadingScreen(loader: albumLoader)
    }
    
    static func queueAll(serverId: Int, folderId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(serverId: Int, tagArtistId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(serverId: Int, tagAlbumId: String) {
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: queueCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func queueAllNext(serverId: Int, folderId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAllNext()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAllNext(serverId: Int, tagArtistId: String) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAllNext()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAllNext(serverId: Int, tagAlbumId: String) {
        queueNextTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: queueCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func playAll(serverId: Int, folderId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(serverId: Int, tagArtistId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(serverId: Int, tagAlbumId: String) {
        preparePlayAll()
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: playCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func shuffleAll(serverId: Int, folderId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(serverId: Int, tagArtistId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(serverId: Int, tagAlbumId: String) {
        preparePlayAll()
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: shuffleCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    private static var metadataQueue: OperationQueue = {
        let metadataQueue = OperationQueue()
        metadataQueue.maxConcurrentOperationCount = 2
        return metadataQueue
    }()
    
    static func downloadMetadata(song: Song) {
        // Download the lyrics
        if song.tagArtistName != nil && song.title.count > 0 {
            if !store.isLyricsCached(song: song), let loader = LyricsLoader(song: song) {
                metadataQueue.addOperation(AsyncLoaderOperation(loader: loader))
            }
        }
        
        // Download the cover art
        if let coverArtId = song.coverArtId {
            let largeLoader = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: true)
            if !largeLoader.isCached {
                metadataQueue.addOperation(AsyncLoaderOperation(loader: largeLoader))
            }
            
            let smallLoader = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: false)
            if !smallLoader.isCached {
                metadataQueue.addOperation(AsyncLoaderOperation(loader: smallLoader))
            }
        }
        
        // Download the TagArtist to ensure it exists for the Downloads tab
        if let tagArtistId = song.tagArtistId, !store.isTagArtistCached(serverId: song.serverId, id: tagArtistId) {
            let loader = TagArtistLoader(serverId: song.serverId, tagArtistId: tagArtistId)
            metadataQueue.addOperation(AsyncLoaderOperation(loader: loader))
        }
        
        // Download the TagAlbum to ensure it's songs exist when offline if opening the tag album from the song in the Downloads tab
        // NOTE: The TagAlbum itself will be downloaded by the TagArtistLoader, but not the songs, so we need to make this second request
        if let tagAlbumId = song.tagAlbumId, (!store.isTagAlbumCached(serverId: song.serverId, id: tagAlbumId) || !store.isTagAlbumSongsCached(serverId: song.serverId, id: tagAlbumId)) {
            let loader = TagAlbumLoader(serverId: song.serverId, tagAlbumId: tagAlbumId)
            metadataQueue.addOperation(AsyncLoaderOperation(loader: loader))
        }
    }
    
    // MARK: Callbacks
    
    private static func downloadCallback(success: Bool, error: Error?) {
        finishLoading()
    }
    
    private static func queueCallback(success: Bool, error: Error?) {
        if success {
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            } else {
                streamManager.fillStreamQueue(startDownload: player.isStarted)
            }
        }
        finishLoading()
    }
    
    private static func playCallback(success: Bool, error: Error?) {
        if success {
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            } else {
                streamManager.fillStreamQueue(startDownload: player.isStarted)
            }
            playQueue.playSong(position: 0)
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
        finishLoading()
    }
    
    private static func shuffleCallback(success: Bool, error: Error?) {
        if success {
            playQueue.shuffleToggle()
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            } else {
                streamManager.fillStreamQueue(startDownload: player.isStarted)
            }
            playQueue.playSong(position: 0)
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
        finishLoading()
    }
    
    // MARK: Internal
    
    private static func preparePlayAll() {
        if settings.isJukeboxEnabled {
            jukebox.clearPlaylist()
        } else {
            _ = store.clearPlayQueue()
        }
        playQueue.isShuffle = false
    }
    
    private static func queueTagAlbum(serverId: Int, tagAlbumId: String, callback: @escaping SuccessErrorCallback) {
        albumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { _, success, error in
            if success, let albumLoader = albumLoader {
                _ = store.queue(songIds: albumLoader.songIds, serverId: serverId)
            }
            callback(success, error)
        }
        albumLoader?.startLoad()
    }
    
    private static func queueNextTagAlbum(serverId: Int, tagAlbumId: String, callback: @escaping SuccessErrorCallback) {
        albumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { _, success, error in
            if success, let albumLoader = albumLoader {
                var offset = 0
                for songId in albumLoader.songIds {
                    if let song = store.song(serverId: serverId, id: songId) {
                        song.queueNext(offset: offset)
                        offset += 1
                    }
                }
            }
            callback(success, error)
        }
        albumLoader?.startLoad()
    }
    
    private static func showLoadingScreen(loader: CancelableLoader?) {
        guard let loader = loader else { return }
        HUD.show {
            HUD.hide()
            loader.cancelLoad()
        }
    }
    
    private static func finishLoading() {
        HUD.hide()
        recursiveLoader = nil
    }
}
