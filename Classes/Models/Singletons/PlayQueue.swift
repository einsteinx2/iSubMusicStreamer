//
//  PlayQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/10/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

enum RepeatMode: Int {
    case none = 0
    case one = 1
    case all = 2
}

// Queue math + Store persistence only (Phase 8.7): all playback orchestration
// (play/start/resume/shuffle/move/remove) lives in PlaybackCoordinator. The settings
// dependency remains solely for the jukebox queue-id selection in currentPlaylistId.
final class PlayQueue: NSObject {
    private let store: Store
    private let settings: SavedSettings

    init(store: Store, settings: SavedSettings) {
        self.store = store
        self.settings = settings
        super.init()
    }

    var currentPlaylistId: Int {
        let id: Int
        if settings.isJukeboxEnabled {
            id = isShuffle ? LocalPlaylist.Default.jukeboxShuffleQueueId : LocalPlaylist.Default.jukeboxPlayQueueId
        } else {
            id = isShuffle ? LocalPlaylist.Default.shuffleQueueId : LocalPlaylist.Default.playQueueId
        }
        return id
    }
    
    var currentPlaylist: LocalPlaylist? {
        store.localPlaylist(id: currentPlaylistId)
    }
    
    var isShuffle = false
    
    var repeatMode: RepeatMode = .none {
        didSet {
            if repeatMode != oldValue {
                // NowPlayingService observes and syncs MPRemoteCommandCenter
                NotificationCenter.postOnMainThread(name: Notifications.repeatModeChanged)
            }
        }
    }
    
    var count: Int {
        if let localPlaylist = store.localPlaylist(id: currentPlaylistId) {
            return localPlaylist.songCount
        }
        return 0
    }
    
    var normalIndex: Int = 0
    var shuffleIndex: Int = 0
    var currentIndex: Int {
        get {
            isShuffle ? shuffleIndex : normalIndex
        }
        set {
            var indexChanged = false
            if isShuffle && shuffleIndex != newValue {
                shuffleIndex = newValue
                indexChanged = true
            } else if normalIndex != newValue {
                normalIndex = newValue
                indexChanged = true
            }
            
            if indexChanged {
                NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistIndexChanged)
            }
        }
    }
    
    var prevIndex: Int {
        let index = currentIndex
        switch repeatMode {
        case .none: return index == 0 ? index : index - 1
        case .one: return index;
        case .all: return index == 0 ? count - 1 : index - 1
        }
    }
    
    var nextIndex: Int {
        let index = currentIndex
        switch repeatMode {
        case .none:
            return song(index: index) == nil && song(index: index + 1) == nil ? index : index + 1
        case .one:
            return index
        case .all:
            return song(index: index + 1) != nil ? index + 1 : 0
        }
    }
    
    var nextIndexIgnoringRepeatMode: Int {
        let index = currentIndex
        return song(index: index) == nil && song(index: index + 1) == nil ? index : index + 1
    }
    
    var currentDisplaySong: Song? {
        // Either the current song, or the previous song if we're past the end of the playlist
        if let song = currentSong {
            return song
        } else {
            return prevSong
        }
    }
    
    var currentSong: Song? {
        return song(index: currentIndex)
    }
    
    var prevSong: Song? {
        return song(index: prevIndex)
    }
    
    var nextSong: Song? {
        return song(index: nextIndex)
    }
    
    func clear() -> Bool {
        return store.clearPlayQueue()
    }
    
    func songs() -> [Song] {
        return store.songs(localPlaylistId: currentPlaylistId)
    }
    
    func song(index: Int) -> Song? {
        return store.song(localPlaylistId: currentPlaylistId, position: index)
    }
    
    func index(offset: Int, fromIndex: Int) -> Int {
        guard let playlist = currentPlaylist, playlist.songCount > 0 else { return 0 }
        let newIndex = offset + fromIndex
        switch repeatMode {
        case .none:
            if newIndex < 0 {
                // If we're less than 0, return 0
                return 0
            } else if newIndex >= playlist.songCount {
                // If we're past the end of the playlist, return the first index past the end
                // (used by the stream prefetcher to know there's nothing more to queue)
                return playlist.songCount
            } else {
                // If we're inside the playlist, return the index
                return newIndex
            }
        case .one:
            // Repeat one always returns the same index
            return fromIndex
        case .all:
            // Wrap around the playlist in either direction
            let wrapped = newIndex % playlist.songCount
            return wrapped < 0 ? wrapped + playlist.songCount : wrapped
        }
    }
    
    func indexFromCurrentIndex(offset: Int) -> Int {
        return index(offset: offset, fromIndex: currentIndex)
    }
    
    @discardableResult
    func decrementIndex() -> Int {
        currentIndex = prevIndex
        return currentIndex
    }
    
    @discardableResult
    func incrementIndex() -> Int {
        currentIndex = nextIndex
        return currentIndex
    }
}
