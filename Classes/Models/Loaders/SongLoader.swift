//
//  SongLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct SongLoader {
    @Injected private static var store: Store
    @Injected private static var settings: Settings
    @Injected private static var jukebox: Jukebox
    @Injected private static var audioEngine: AudioEngine
    @Injected private static var playQueue: PlayQueue
    @Injected private static var streamManager: StreamManager
    
    private static var recursiveLoader: RecursiveSongLoader?
    private static var albumLoader: TagAlbumLoader?
    
    // MARK: Public Helper Functions
    
    static func downloadAll(folderId: Int) {
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(tagArtistId: Int) {
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(tagAlbumId: Int) {
        albumLoader = TagAlbumLoader(tagAlbumId: tagAlbumId) { success, error in
            if success, let albumLoader = albumLoader {
                _ = store.addToDownloadQueue(serverId: albumLoader.serverId, songIds: albumLoader.songIds)
            }
            downloadCallback(success: success, error: error)
        }
        albumLoader?.startLoad()
        showLoadingScreen(loader: albumLoader)
    }
    
    static func queueAll(folderId: Int) {
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(tagArtistId: Int) {
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(tagAlbumId: Int) {
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: queueCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func playAll(folderId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(tagArtistId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(tagAlbumId: Int) {
        preparePlayAll()
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: playCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func shuffleAll(folderId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(tagArtistId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(tagAlbumId: Int) {
        preparePlayAll()
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: shuffleCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
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
                let isStarted = audioEngine.player?.isStarted ?? false
                streamManager.fillStreamQueue(isStarted)
            }
        }
        finishLoading()
    }
    
    private static func playCallback(success: Bool, error: Error?) {
        if success {
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            } else {
                let isStarted = audioEngine.player?.isStarted ?? false
                streamManager.fillStreamQueue(isStarted)
            }
            playQueue.playSong(position: 0)
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        }
        finishLoading()
    }
    
    private static func shuffleCallback(success: Bool, error: Error?) {
        if success {
            if settings.isJukeboxEnabled {
                jukebox.clearRemotePlaylist()
            }
            playQueue.shuffleToggle()
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            } else {
                let isStarted = audioEngine.player?.isStarted ?? false
                streamManager.fillStreamQueue(isStarted)
            }
            playQueue.playSong(position: 0)
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
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
    
    private static func queueTagAlbum(tagAlbumId: Int, callback: @escaping LoaderCallback) {
        albumLoader = TagAlbumLoader(tagAlbumId: tagAlbumId) { success, error in
            if success, let albumLoader = albumLoader {
                _ = store.queue(songIds: albumLoader.songIds, serverId: albumLoader.serverId)
            }
            callback(success, error)
        }
        albumLoader?.startLoad()
    }
    
    private static func showLoadingScreen(loader: CancelableLoader?) {
        guard let loader = loader else { return }
        HUD.show {
            loader.cancelLoad()
            HUD.hide()
        }
    }
    
    private static func finishLoading() {
        HUD.hide()
        recursiveLoader = nil
    }
}
