//
//  RecursiveSongLoaderWrapper.swift
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

fileprivate var recursiveLoader: RecursiveSongLoader?
fileprivate var albumLoader: TagAlbumLoader?

@objc class SongLoader: NSObject {
    
    // MARK: Public Helper Functions
    
    @objc static func downloadAll(folderId: String) {
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func downloadAll(tagArtistId: String) {
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: downloadCallback(success:error:))
        recursiveLoader?.downloadAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func downloadAll(tagAlbumId: String) {
        albumLoader = TagAlbumLoader(albumId: tagAlbumId) { success, error in
            if success {
                albumLoader?.songs.forEach { $0.addToCacheQueueDbQueue() }
            }
            downloadCallback(success: success, error: error)
        }
        albumLoader?.startLoad()
        showLoadingScreen(sender: albumLoader)
    }
    
    @objc static func queueAll(folderId: String) {
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func queueAll(tagArtistId: String) {
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: queueCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func queueAll(tagAlbumId: String) {
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: queueCallback(success:error:))
        showLoadingScreen(sender: albumLoader)
    }
    
    @objc static func playAll(folderId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func playAll(tagArtistId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: playCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func playAll(tagAlbumId: String) {
        preparePlayAll()
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: playCallback(success:error:))
        showLoadingScreen(sender: albumLoader)
    }
    
    @objc static func shuffleAll(folderId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(folderId: folderId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func shuffleAll(tagArtistId: String) {
        preparePlayAll()
        recursiveLoader = RecursiveSongLoader(tagArtistId: tagArtistId, callback: shuffleCallback(success:error:))
        recursiveLoader?.queueAll()
        showLoadingScreen(sender: recursiveLoader)
    }
    
    @objc static func shuffleAll(tagAlbumId: String) {
        preparePlayAll()
        queueTagAlbum(tagAlbumId: tagAlbumId, callback: shuffleCallback(success:error:))
        showLoadingScreen(sender: albumLoader)
    }
    
    // MARK: Callbacks
    
    private static func downloadCallback(success: Bool, error: Error?) {
        finishLoading()
    }
    
    private static func queueCallback(success: Bool, error: Error?) {
        if success {
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().replacePlaylistWithLocal()
            } else {
                let isStarted = AudioEngine.shared().player?.isStarted ?? false
                StreamManager.shared().fillStreamQueue(isStarted)
            }
        }
        finishLoading()
    }
    
    private static func playCallback(success: Bool, error: Error?) {
        if success {
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().replacePlaylistWithLocal()
            } else {
                let isStarted = AudioEngine.shared().player?.isStarted ?? false
                StreamManager.shared().fillStreamQueue(isStarted)
            }
            Music.shared().showPlayer()
        }
        finishLoading()
    }
    
    private static func shuffleCallback(success: Bool, error: Error?) {
        if success {
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().clearRemotePlaylist()
            }
            DatabaseOld.shared().shufflePlaylist()
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().replacePlaylistWithLocal()
            } else {
                let isStarted = AudioEngine.shared().player?.isStarted ?? false
                StreamManager.shared().fillStreamQueue(isStarted)
            }
            Music.shared().showPlayer()
        }
        finishLoading()
    }
    
    // MARK: Internal
    
    private static func preparePlayAll() {
        if Settings.shared().isJukeboxEnabled {
            Jukebox.shared().clearPlaylist()
        } else {
            DatabaseOld.shared().resetCurrentPlaylistDb()
        }
        PlayQueue.shared().isShuffle = false
    }
    
    private static func queueTagAlbum(tagAlbumId: String, callback: @escaping LoaderCallback) {
        albumLoader = TagAlbumLoader(albumId: tagAlbumId) { success, error in
            if success {
                albumLoader?.songs.forEach { $0.addToCurrentPlaylistDbQueue() }
            }
            callback(success, error)
        }
        albumLoader?.startLoad()
    }
    
    private static func showLoadingScreen(sender: Any?) {
        guard let sender = sender else { return }
        ViewObjects.shared().showAlbumLoadingScreenOnMainWindowWithSender(sender)
    }
    
    private static func finishLoading() {
        ViewObjects.shared().hideLoadingScreen()
        recursiveLoader = nil
    }
}
