//
//  AsyncSongsHelper.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

struct AsyncSongsHelper {
    @Injected private static var store: Store
    @Injected private static var settings: SavedSettings
    @Injected private static var jukebox: Jukebox
    @Injected private static var player: BassPlayer
    @Injected private static var playQueue: PlayQueue
    @Injected private static var streamManager: StreamManager
    
    // MARK: Public Helper Functions
    
    static func downloadAll(serverId: Int, folderId: String) {
        loadRecursive(serverId: serverId, id: folderId, idType: .folder, action: .downloadAll)
    }
    
    static func downloadAll(serverId: Int, tagArtistId: String) {
        loadRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, action: .downloadAll)
    }
    
    static func downloadAll(serverId: Int, tagAlbumId: String) {
        loadTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, action: .downloadAll)
    }
    
    static func queueAll(serverId: Int, folderId: String) {
        loadRecursive(serverId: serverId, id: folderId, idType: .folder, action: .queueAll)
    }
    
    static func queueAll(serverId: Int, tagArtistId: String) {
        loadRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, action: .queueAll)
    }
    
    static func queueAll(serverId: Int, tagAlbumId: String) {
        loadTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, action: .queueAll)
    }
    
    static func queueAllNext(serverId: Int, folderId: String) {
        loadRecursive(serverId: serverId, id: folderId, idType: .folder, action: .queueAllNext)
    }
    
    static func queueAllNext(serverId: Int, tagArtistId: String) {
        loadRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, action: .queueAllNext)
    }
    
    static func queueAllNext(serverId: Int, tagAlbumId: String) {
        loadTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, action: .queueAllNext)
    }
    
    static func playAll(serverId: Int, folderId: String) {
        loadRecursive(serverId: serverId, id: folderId, idType: .folder, action: .playAll)
    }
    
    static func playAll(serverId: Int, tagArtistId: String) {
        loadRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, action: .playAll)
    }
    
    static func playAll(serverId: Int, tagAlbumId: String) {
        loadTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, action: .playAll)
    }
    
    static func shuffleAll(serverId: Int, folderId: String) {
        loadRecursive(serverId: serverId, id: folderId, idType: .folder, action: .shuffleAll)
    }
    
    static func shuffleAll(serverId: Int, tagArtistId: String) {
        loadRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, action: .shuffleAll)
    }
    
    static func shuffleAll(serverId: Int, tagAlbumId: String) {
        loadTagAlbum(serverId: serverId, tagAlbumId: tagAlbumId, action: .shuffleAll)
    }
    
    static func downloadMetadata(song: Song, manager: AsyncCoverArtLoaderManager = AsyncCoverArtLoaderManager.shared) {
        Task {
            // Download the lyrics
            if song.tagArtistName != nil && song.title.count > 0 {
                if !store.isLyricsCached(song: song) {
                    _ = try? await AsyncLyricsLoader(song: song)?.load()
                }
            }
            
            // Download the cover art
            if let coverArtId = song.coverArtId {
                _ = await manager.download(serverId: song.serverId, coverArtId: coverArtId, isLarge: true)
                _ = await manager.download(serverId: song.serverId, coverArtId: coverArtId, isLarge: false)
            }
            
            // Download the TagArtist to ensure it exists for the Downloads tab
            if let tagArtistId = song.tagArtistId, !store.isTagArtistCached(serverId: song.serverId, id: tagArtistId) {
                _ = try? await AsyncTagArtistLoader(serverId: song.serverId, tagArtistId: tagArtistId).load()
            }
            
            // Download the TagAlbum to ensure it's songs exist when offline if opening the tag album from the song in the Downloads tab
            // NOTE: The TagAlbum itself will be downloaded by the TagArtistLoader, but not the songs, so we need to make this second request
            if let tagAlbumId = song.tagAlbumId, (!store.isTagAlbumCached(serverId: song.serverId, id: tagAlbumId) || !store.isTagAlbumSongsCached(serverId: song.serverId, id: tagAlbumId)) {
                _ = try? await AsyncTagAlbumLoader(serverId: song.serverId, tagAlbumId: tagAlbumId).load()
            }
        }
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
    
    private static func finishQueue() {
        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        } else {
            streamManager.fillStreamQueue(startDownload: player.isStarted)
        }
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
    }
    
    private static func finishPlay() {
        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        } else {
            streamManager.fillStreamQueue(startDownload: player.isStarted)
        }
        playQueue.playSong(position: 0)
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
        NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
    }
    
    private static func finishShuffle() {
        playQueue.shuffleToggle()
        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        } else {
            streamManager.fillStreamQueue(startDownload: player.isStarted)
        }
        playQueue.playSong(position: 0)
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
        NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
    }
    
    private static func loadRecursive(serverId: Int, id: String, idType: RecursiveSongLoaderIdType, action: RecursiveSongLoaderAction) {
        if action == .playAll || action == .shuffleAll {
            preparePlayAll()
        }
        
        let task = Task {
            do {
                defer {
                    HUD.hide()
                }
                try await AsyncRecursiveSongLoader.load(serverId: serverId, id: id, idType: idType, action: action)
                
                switch action {
                case .playAll:
                    finishPlay()
                case .queueAll, .queueAllNext:
                    finishQueue()
                case .shuffleAll:
                    finishShuffle()
                default: break
                }
                
            } catch {
                DDLogError("[AsyncSongsHelper]loadRecursive of id \(id) with type \(idType) with action \(action) failed with error: \(error)")
            }
        }
        HUD.show {
            task.cancel()
            HUD.hide()
        }
    }
    
    private static func loadTagAlbum(serverId: Int, tagAlbumId: String, action: RecursiveSongLoaderAction) {
        if action == .playAll || action == .shuffleAll {
            preparePlayAll()
        }
        
        let task = Task {
            do {
                let songIds = try await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId).load()
                
                switch action {
                case .downloadAll:
                    _ = store.addToDownloadQueue(serverId: serverId, songIds: songIds)
                case .playAll:
                    _ = store.queue(songIds: songIds, serverId: serverId)
                    finishPlay()
                case .queueAll:
                    _ = store.queue(songIds: songIds, serverId: serverId)
                    finishQueue()
                case .queueAllNext:
                    var offset = 0
                    for songId in songIds {
                        if let song = store.song(serverId: serverId, id: songId) {
                            song.queueNext(offset: offset)
                            offset += 1
                        }
                    }
                    finishQueue()
                default: break
                }
                
            } catch {
                DDLogError("[AsyncSongsHelper] loadTagAlbum of tagAlbumId \(tagAlbumId) with action \(action) failed with error: \(error)")
                HUD.hide()
            }
        }
        HUD.show {
            task.cancel()
            HUD.hide()
        }
    }
}
