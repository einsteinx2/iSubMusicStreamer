//
//  PlayQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/10/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import MediaPlayer
import Resolver

@objc enum RepeatMode: Int {
    case none = 0
    case one = 1
    case all = 2
}

@objc final class PlayQueue: NSObject {
    @Injected private var settings: Settings
    @Injected private var jukebox: Jukebox
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: PlayQueue { Resolver.resolve() }
    
    @Injected private var store: Store
    
    private var currentPlaylistId: Int {
        let id: Int
        if settings.isJukeboxEnabled {
            id = isShuffle ? LocalPlaylist.Default.jukeboxShuffleQueueId : LocalPlaylist.Default.jukeboxPlayQueueId
        } else {
            id = isShuffle ? LocalPlaylist.Default.shuffleQueueId : LocalPlaylist.Default.playQueueId
        }
        return id
    }
    
    private var currentPlaylist: LocalPlaylist? {
        store.localPlaylist(id: currentPlaylistId)
    }
    
    @objc var isShuffle = false
    
    @objc var repeatMode: RepeatMode = .none {
        didSet {
            if repeatMode != oldValue {
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_RepeatModeChanged)
                
                let repeatType: MPRepeatType
                switch repeatMode {
                case .none: repeatType = .off
                case .one: repeatType = .one
                case .all: repeatType = .all
                }
                MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = repeatType
            }
        }
    }
    
    @objc var count: Int {
        if let localPlaylist = store.localPlaylist(id: currentPlaylistId) {
            return localPlaylist.songCount
        }
        return 0
    }
    
    @objc var normalIndex: Int = 0
    @objc var shuffleIndex: Int = 0
    @objc var currentIndex: Int {
        get {
            isShuffle ? shuffleIndex : normalIndex
        }
        set {
            var indexChanged = false
            if isShuffle && shuffleIndex != newValue {
                shuffleIndex = newValue
                indexChanged = true
            } else if self.normalIndex != newValue {
                normalIndex = newValue
                indexChanged = true
            }
            
            if indexChanged {
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistIndexChanged)
            }
        }
    }
    
    @objc var prevIndex: Int {
        let index = currentIndex
        switch repeatMode {
        case .none: return index == 0 ? index : index - 1
        case .one: return index;
        case .all: return index == 0 ? count - 1 : index - 1
        }
    }
    
    @objc var nextIndex: Int {
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
    
    @objc var currentDisplaySong: Song? {
        // Either the current song, or the previous song if we're past the end of the playlist
        if let song = currentSong {
            return song
        } else {
            return prevSong
        }
    }
    
    @objc var currentSong: Song? {
        return song(index: currentIndex)
    }
    
    @objc var prevSong: Song? {
        return song(index: prevIndex)
    }
    
    @objc var nextSong: Song? {
        return song(index: nextIndex)
    }
    
    @objc func removeSongs(indexes: [Int]) {
        // TODO: implement this
        fatalError("implement this")
    }
    
    @objc func song(index: Int) -> Song? {
        store.song(localPlaylistId: currentPlaylistId, position: index)
    }
    
    @objc func moveSong(fromIndex: Int, toIndex: Int) -> Bool {
        if store.move(songAtPosition: fromIndex, toPosition: toIndex, localPlaylistId: currentPlaylistId) {
            if settings.isJukeboxEnabled {
                jukebox.replacePlaylistWithLocal()
            }
            
            // Correct the value of currentPlaylistPosition
            if fromIndex == currentIndex {
                currentIndex = toIndex
            } else if fromIndex < currentIndex && toIndex >= currentIndex {
                currentIndex -= 1
            } else if fromIndex > currentIndex && toIndex <= currentIndex {
                currentIndex += 1
            }
            return true
        }
        return false
    }
    
    // TODO: Fix this logic and write unit tests
    @objc func index(offset: Int, fromIndex: Int) -> Int {
        guard let playlist = currentPlaylist else { return 0 }
        var newIndex = offset + fromIndex
        switch repeatMode {
        case .none:
            if newIndex < 0 {
                // If we're less than 0, return 0
                return newIndex
            } else if newIndex >= playlist.songCount {
                // If we're past the end of the playlist, return the first index past the end
                return playlist.songCount
            } else {
                // If we're inside the playlist, return the index
                return newIndex
            }
        case .one:
            // Repeat one always returns the same index
            return fromIndex
        case .all:
            if newIndex < 0 {
                // If we're less than 0, wrap around the playlist
                while newIndex < 0 {
                    newIndex += playlist.songCount
                }
                return newIndex
            } else if newIndex >= playlist.songCount {
                // If we're past the end of the playlist, wrap around
                return newIndex - playlist.songCount
            } else {
                // If we're inside the playlist, return the index
                return newIndex
            }
        }
    }
    
    @objc func indexFromCurrentIndex(offset: Int) -> Int {
        return index(offset: offset, fromIndex: currentIndex)
    }
    
    @objc func decrementIndex() -> Int {
        currentIndex = prevIndex
        return currentIndex
    }
    
    @objc func incrementIndex() -> Int {
        currentIndex = nextIndex
        return currentIndex
    }
    
    @objc func shuffleToggle() {
        fatalError("implement this")
        if isShuffle {
            
        } else {
            
        }
    }
}
