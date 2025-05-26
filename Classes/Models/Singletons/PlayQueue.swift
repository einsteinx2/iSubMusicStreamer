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
import CocoaLumberjackSwift

@objc enum RepeatMode: Int {
    case none = 0
    case one = 1
    case all = 2
}

@objc final class PlayQueue: NSObject {
    @LazyInjected private var settings: SavedSettings
    @LazyInjected private var jukebox: Jukebox
    @LazyInjected private var streamManager: StreamManager
    @LazyInjected private var downloadQueue: DownloadQueue
    @LazyInjected private var player: BassPlayer
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: PlayQueue { Resolver.resolve() }
    
    @Injected private var store: Store
    
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
    
    @objc var isShuffle = false
    
    @objc var repeatMode: RepeatMode = .none {
        didSet {
            if repeatMode != oldValue {
                NotificationCenter.postOnMainThread(name: Notifications.repeatModeChanged)
                
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
            } else if normalIndex != newValue {
                normalIndex = newValue
                indexChanged = true
            }
            
            if indexChanged {
                NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistIndexChanged)
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
    
    @objc func removeSongs(indexes: [Int]) -> Bool {
        if store.remove(songsAtPositions: indexes, localPlaylistId: currentPlaylistId) {
            // Stop the player if we deleted the current song
            if indexes.contains(currentIndex) {
                player.stop()
                currentIndex = 0
            }
            return true
        }
        return false
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
    
    @objc @discardableResult
    func decrementIndex() -> Int {
        currentIndex = prevIndex
        return currentIndex
    }
    
    @objc @discardableResult
    func incrementIndex() -> Int {
        currentIndex = nextIndex
        return currentIndex
    }
    
    /// Called when the shuffle button is pushed.
    @objc func shuffleToggle() {
       if isShuffle {
           if let shuffleCurrentSong = currentSong {
               isShuffle = false
               if let currentPosition = store.getSongPosition(localPlaylistId: LocalPlaylist.Default.playQueueId, songId: shuffleCurrentSong.id) {
                   normalIndex = currentPosition
                   if let shuffleQueueCurrentSong = song(index: currentPosition) {
                       streamManager.removeAllStreams(except: shuffleQueueCurrentSong)
                       streamManager.fillStreamQueue(startDownload: true)
                   }
               }
           }
       } else {
           if store.createShuffleQueue(currentPosition: normalIndex) {
               shuffleIndex = 0
               isShuffle = true
               if let currentSong = song(index: normalIndex) {
                   streamManager.removeAllStreams(except: currentSong)
                   streamManager.fillStreamQueue(startDownload: true)
               }
           }
       }
    }
    
    @discardableResult
    func playSong(position: Int) -> Song? {
        currentIndex = position
        guard let currentSong = self.currentSong else { return nil }
        
        return DispatchQueue.mainSyncSafe {
            if !currentSong.isVideo {
                // Remove the video player if this is not a video
                NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)
            }
            
            if settings.isJukeboxEnabled {
                if currentSong.isVideo {
                    SlidingNotification.showOnMainWindow(message: "Cannot play videos in Jukebox mode.")
                    return nil
                } else {
                    jukebox.playSong(index: position)
                }
            } else {
                streamManager.removeAllStreams(except: currentSong)
                if currentSong.isVideo {
                    NotificationCenter.postOnMainThread(name: Notifications.playVideo, userInfo: ["song": currentSong])
                } else {
                    startSong()
                }
            }
            return currentSong
        }
    }
    
    @discardableResult
    func playPrevSong() -> Song? {
        DDLogVerbose("[PlayQueue] playPrevSong called");
        if player.progress > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            DDLogVerbose("[PlayQueue] playPrevSong Past 10 seconds in the song, so restart playback instead of changing songs, calling playSong(position: \(currentIndex))")
            return playSong(position: currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            DDLogVerbose("[PlayQueue] playPrevSong within first 10 seconds, so go to previous, calling playSong(position: \(prevIndex))")
            return playSong(position: prevIndex)
        }
    }
    
    @discardableResult
    func playNextSong() -> Song? {
        DDLogVerbose("[PlayQueue] playNextSong called, calling playSong(position: \(nextIndex))")
        return playSong(position: nextIndex)
    }
    
    @discardableResult
    func playCurrentSong() -> Song? {
        DDLogVerbose("[PlayQueue] playCurrentSong called, calling playSong(position: \(currentIndex))")
        return playSong(position: currentIndex)
    }
    
    // Resume song after iSub shuts down
    @discardableResult
    func resumeSong() -> Song? {
        if let currentSong = currentSong, settings.isRecover {
            startSong(offsetInBytes: settings.byteOffset, offsetInSeconds: settings.seekTime)
            return currentSong
        } else {
            player.startByteOffset = settings.byteOffset
            player.startSecondsOffset = settings.seekTime
            return nil
        }
    }
    
    @objc func updateLockScreenInfo() {
        DispatchQueue.main.async {
            var info = [String: Any]()
            
            if let song = self.currentSong {
                info[MPMediaItemPropertyTitle] = song.title
                info[MPMediaItemPropertyAlbumTitle] = song.tagAlbumName
                info[MPMediaItemPropertyArtist] = song.tagArtistName
                info[MPMediaItemPropertyGenre] = song.genre
                if song.duration > 0 {
                    info[MPMediaItemPropertyPlaybackDuration] = song.duration
                }
                info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = self.currentIndex
                info[MPNowPlayingInfoPropertyPlaybackQueueCount] = self.count
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.player.progress
                info[MPNowPlayingInfoPropertyPlaybackRate] = 1
                
                if let coverArtId = song.coverArtId, self.settings.isLockScreenArtEnabled {
                    let artLoader = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: true)
                    if let image = artLoader.coverArtImage {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { size -> UIImage in
                            return image
                        }
                        info[MPMediaItemPropertyArtwork] = artwork
                    }
                }
            }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            
            // Run this every 30 seconds to update the progress and keep it in sync
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateLockScreenInfo), object: nil)
            self.perform(#selector(self.updateLockScreenInfo), with: nil, afterDelay: 30)
        }
    }
    
    // MARK: Old MusicSingleton start song functions
    // TODO: Refactor this craziness
    
    @objc func startSong() {
        startSong(offsetInBytes: 0, offsetInSeconds: 0)
    }
    
    private var offsetInBytes = 0
    private var offsetInSeconds = 0.0
    @objc func startSong(offsetInBytes bytes: Int, offsetInSeconds seconds: Double) {
        DispatchQueue.mainSyncSafe {
            // Destroy the streamer/video player to start a new song
            player.stop()
            NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)
            
            guard currentSong != nil else { return }
            
            offsetInBytes = bytes
            offsetInSeconds = seconds
            
            // Only start the caching process if it's been a half second after the last request. Prevents crash when skipping through playlist fast
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startSongAtOffsetsInternal), object: nil)
            perform(#selector(startSongAtOffsetsInternal), with: nil, afterDelay: 1)
        }
    }
    
    @objc private func startSongAtOffsetsInternal() {
        guard let song = currentSong else { return }
        let index = currentIndex
        
        // Fix for bug that caused songs to sometimes start playing then immediately restart
        if player.isPlaying, let playerSong = player.currentStream?.song, playerSong == song {
            // We're already playing this song so bail
            return
        }
        
        // Check to see if the song is already cached
        if song.isFullyCached {
            // The song is fully cached, start streaming from the local copy
            player.startNewSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
            
            // Fill the stream queue
            if !settings.isOfflineMode {
                streamManager.fillStreamQueue(startDownload: true)
                //[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
            }
        } else if !song.isFullyCached && settings.isOfflineMode {
            playNextSong()
        } else {
            if let currentQueuedSong = downloadQueue.currentQueuedSong, currentQueuedSong == song {
                // The cache queue is downloading this song, remove it before continuing
                _ = downloadQueue.removeCurrentSong()
            }
            
            if streamManager.isDownloading(song: song) {
                // The song is caching, start streaming from the local copy
                if let handler = streamManager.handler(song: song), !player.isPlaying, !handler.isDelegateNotifiedToStartPlayback {
                    // Only start the player if the handler isn't going to do it itself
                    player.startNewSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
                }
            } else if streamManager.isFirstInQueue(song: song) && !streamManager.isDownloading {
                // The song is first in queue, but the queue is not downloading. Probably the song was downloading when the app quit. Resume the download and start the player
                streamManager.resumeQueue()
                
                // The song is caching, start streaming from the local copy
                if let handler = streamManager.handler(song: song), !player.isPlaying, !handler.isDelegateNotifiedToStartPlayback {
                    // Only start the player if the handler isn't going to do it itself
                    player.startNewSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
                }
            } else {
                // Clear the stream manager
                streamManager.removeAllStreams()
                
                // Start downloading the current song from the correct offset
                streamManager.queueStream(song: song,
                                          byteOffset: offsetInBytes,
                                          secondsOffset: offsetInSeconds,
                                          index: 0,
                                          tempCache: offsetInBytes > 0 || !settings.isSongCachingEnabled,
                                          startDownload: true)
                
                // Fill the stream queue
                if settings.isSongCachingEnabled {
                    streamManager.fillStreamQueue(startDownload: player.isStarted)
                }
            }
        }
    }
}

