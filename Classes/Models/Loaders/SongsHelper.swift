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
    @Injected private static var settings: Settings
    @Injected private static var jukebox: Jukebox
    @Injected private static var player: BassGaplessPlayer
    @Injected private static var playQueue: PlayQueue
    @Injected private static var streamManager: StreamManager
    
    private static var recursiveLoader: RecursiveSongLoader?
    private static var albumLoader: TagAlbumLoader?
    
    // MARK: Public Helper Functions
    
    static func downloadAll(serverId: Int, folderId: Int) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(serverId: Int, tagArtistId: Int) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func downloadAll(serverId: Int, tagAlbumId: Int) {
        albumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { _, success, error in
            if success, let albumLoader = albumLoader {
                _ = store.addToDownloadQueue(serverId: serverId, songIds: albumLoader.songIds)
            }
            downloadCallback(success: success, error: error)
        }
        albumLoader?.startLoad()
        showLoadingScreen(loader: albumLoader)
    }
    
    static func queueAll(serverId: Int, folderId: Int) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(serverId: Int, tagArtistId: Int) {
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func queueAll(serverId: Int, tagAlbumId: Int) {
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: queueCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func playAll(serverId: Int, folderId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(serverId: Int, tagArtistId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func playAll(serverId: Int, tagAlbumId: Int) {
        preparePlayAll()
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: playCallback(success:error:))
        showLoadingScreen(loader: albumLoader)
    }
    
    static func shuffleAll(serverId: Int, folderId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, folderId: folderId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(serverId: Int, tagArtistId: Int) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(serverId: serverId, tagArtistId: tagArtistId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(loader: recursiveLoader)
    }
    
    static func shuffleAll(serverId: Int, tagAlbumId: Int) {
        preparePlayAll()
        queueTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, callback: shuffleCallback(success:error:))
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
            if settings.isJukeboxEnabled {
                jukebox.clearRemotePlaylist()
            }
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
    
    private static func queueTagAlbum(serverId: Int, tagAlbumId: Int, callback: @escaping SuccessErrorCallback) {
        albumLoader = TagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId) { _, success, error in
            if success, let albumLoader = albumLoader {
                _ = store.queue(songIds: albumLoader.songIds, serverId: serverId)
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
