//
//  StreamManager.swift
//  iSub Release
//
//  Created by Benjamin Baron on 1/21/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

@objc final class StreamManager: NSObject {
    @LazyInjected private var cacheQueue: CacheQueue
    @LazyInjected private var store: Store
    @LazyInjected private var settings: Settings
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var player: BassPlayer
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: StreamManager { Resolver.resolve() }
    
    private let defaultNumberOfStreamsToQueue = 2
    private let maxNumberOfReconnects = 5
    
    private var handlerStack = [StreamHandler]()
    @objc private(set) var lastCachedSong: Song?
    @objc private(set) var lastTempCachedSong: Song?
    
    func setup() {
        // Load the handler stack, it may have been full when iSub was closed
        loadHandlerStack()
        
        if let firstHandler = handlerStack.first {
            if firstHandler.isTempCache {
                removeAllStreams()
            } else {
                for handler in handlerStack {
                    // Resume any handlers that were downloading when iSub closed
                    if handler.isDownloading && !handler.isTempCache {
                        handler.start(resume: true)
                    }
                }
            }
        }
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songCachingToggled), name: Notifications.songCachingEnabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songCachingToggled), name: Notifications.songCachingDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(currentPlaylistIndexChanged), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(currentPlaylistOrderChanged), name: Notifications.repeatModeChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(currentPlaylistOrderChanged), name: Notifications.currentPlaylistOrderChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(currentPlaylistOrderChanged), name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songPlaybackEnded), name: Notifications.songPlaybackEnded)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    var currentStreamingSong: Song? {
        guard isDownloading else { return nil }
        return handlerStack.first?.song
    }
    
    var firstHandlerInQueue: StreamHandler? {
        return handlerStack.first
    }
    
    @objc func handler(song: Song) -> StreamHandler? {
        return handlerStack.first { $0.song == song }
    }
    
    func isFirstInQueue(song: Song) -> Bool {
        guard let firstSong = handlerStack.first?.song else { return false }
        return firstSong == song
    }
    
    func isInQueue(song: Song) -> Bool {
        return handlerStack.contains { $0.song == song }
    }
    
    func isDownloading(song: Song) -> Bool {
        return handler(song: song)?.isDownloading ?? false
    }
    
    var isDownloading: Bool {
        return handlerStack.contains { $0.isDownloading }
    }
    
    func cancelAllStreams(except handlers: [StreamHandler]) {
        for handler in handlerStack {
            if handlers.contains(handler) { continue }
            cancelResume(handler: handler)
            handler.cancel()
        }
        saveHandlerStack()
    }
    
    func cancelAllStreams(except songs: [Song]) {
        let handlers = songs.compactMap { handler(song: $0)}
        cancelAllStreams(except: handlers)
    }
    
    func cancelAllStreams(except song: Song) {
        guard let handler = handler(song: song) else { return }
        cancelAllStreams(except: [handler])
    }
    
    func cancelAllStreams() {
        cancelAllStreams(except: [] as [StreamHandler])
    }
    
    func cancelStream(handler: StreamHandler) {
        cancelResume(handler: handler)
        handler.cancel()
        saveHandlerStack()
    }
    
    func cancelStream(index: Int) {
        guard index >= 0 && index < handlerStack.count else { return }
        cancelStream(handler: handlerStack[index])
    }
    
    func cancelStream(song: Song) {
        guard let handler = handlerStack.first(where: { $0.song == song }) else { return }
        cancelStream(handler: handler)
    }
    
    private func removeStreamWithoutSavingStack(handler: StreamHandler) {
        // Cancel the handler
        cancelResume(handler: handler)
        handler.cancel()
        
        // Remove the handler
        handlerStack.removeAll { $0 == handler }
        
        // Remove the song from downloads if necessary
        let song = handler.song
        guard let currentQueuedSong = cacheQueue.currentQueuedSong, currentQueuedSong == song else { return }
        // TODO: Why is this checking if the CacheQueue is downloading?
        if currentQueuedSong != song && !song.isFullyCached && !song.isTempCached && cacheQueue.isDownloading {
            DDLogInfo("[StreamManager] Removing song from cached songs table: \(song)")
            _ = store.deleteDownloadedSong(song: song)
        }
    }
    
    func removeAllStreams(except handlers: [StreamHandler]) {
        // Remove the handlers
        let handlerStackCopy = handlerStack
        for handler in handlerStackCopy {
            if handlers.contains(handler) { continue }
            removeStreamWithoutSavingStack(handler: handler)
        }
        
        // Start the next handler
        if let handler = handlerStack.first, !handler.isDownloading {
            handler.start()
        }
        
        saveHandlerStack()
    }
    
    func removeAllStreams(except songs: [Song]) {
        let handlers = songs.compactMap { handler(song: $0)}
        removeAllStreams(except: handlers)
    }
    
    func removeAllStreams(except song: Song) {
        guard let handler = handler(song: song) else { return }
        removeAllStreams(except: [handler])
    }
    
    @objc func removeAllStreams() {
        removeAllStreams(except: [] as [StreamHandler])
    }
    
    func removeStream(handler: StreamHandler) {
        // Remove the handler
        removeStreamWithoutSavingStack(handler: handler)
        
        // Start the next handler
        if let handler = handlerStack.first, !handler.isDownloading {
            handler.start()
        }
        
        saveHandlerStack()
    }
    
    func removeStream(index: Int) {
        guard index >= 0 && index < handlerStack.count else { return }
        removeStream(handler: handlerStack[index])
    }
    
    func removeStream(song: Song) {
        guard let handler = handlerStack.first(where: { $0.song == song }) else { return }
        removeStream(handler: handler)
    }
    
    private func cancelResume(handler: StreamHandler) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resume(handler:)), object: handler)
    }
    
    @objc func resume(handler: StreamHandler) {
        // As an added check, verify that this handler is still in the stack
        guard isInQueue(song: handler.song) else { return }
        if cacheQueue.isDownloading, let currentQueuedSong = cacheQueue.currentQueuedSong, currentQueuedSong == handler.song {
            // This song is already being downloaded by the cache queue, so just start the player
            streamHandlerStartPlayback(handler: handler)
            
            // Remove the handler from the stack
            removeStream(handler: handler)
            
            // Start the next handler which is now the first object
            if let handler = handlerStack.first, !handler.isDownloading {
                handler.start()
            }
        } else {
            handler.start(resume: true)
        }
    }
    
    func resumeQueue() {
        guard let handler = handlerStack.first else { return }
        resume(handler: handler)
    }
    
    func start(handler: StreamHandler, resume: Bool) {
        // As an added check, verify that this handler is still in the stack
        guard isInQueue(song: handler.song) else { return }
        DDLogInfo("[StreamManager] starting handler \(handler) resume: \(resume), handlerStack: \(handlerStack)")
        if cacheQueue.isDownloading, let currentQueuedSong = cacheQueue.currentQueuedSong, currentQueuedSong == handler.song {
            // This song is already being downloaded by the cache queue, so just start the player
            streamHandlerStartPlayback(handler: handler)
            
            // Remove the handler from the stack
            removeStream(handler: handler)
            
            // Start the next handler which is now the first object
            if let handler = handlerStack.first, !handler.isDownloading {
                handler.start()
            }
        } else {
            handler.start(resume: resume)
        }
    }
    
    func start(handler: StreamHandler) {
        start(handler: handler, resume: false)
    }
    
    private let handlerStackKey = "handlerStack"
    
    func saveHandlerStack() {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(handlerStack), forKey: handlerStackKey)
            UserDefaults.standard.synchronize()
        } catch {
            DDLogError("[StreamManager] saveHandlerStack: failed to archive handler stack \(error)")
        }
    }
    
    func loadHandlerStack() {
        do {
            guard let data = UserDefaults.standard.object(forKey: handlerStackKey) as? Data else { return }
            handlerStack = try JSONDecoder().decode(from: data)
            handlerStack.forEach { $0.delegate = self }
            DDLogInfo("[StreamManager] loaded handler stack \(handlerStack)")
        } catch {
            DDLogError("[StreamManager] saveHandlerStack: failed to unarchive handler stack \(error)")
        }
    }
    
    // MARK: Handler Stealing
    
    @objc func stealForCacheQueue(handler: StreamHandler) {
        DDLogInfo("[StreamManager] cache queue manager stole handler for song \(handler.song)")
        handlerStack.removeAll { $0 == handler }
        saveHandlerStack()
        fillStreamQueue()
    }
    
    // MARK: Download
    
    // TODO: implement this (queue the 5 loaders so that they execute sequentially)
    func queueStream(song: Song, byteOffset: Int = 0, secondsOffset: Double = 0.0, index: Int, tempCache: Bool, startDownload: Bool) {
        guard index >= 0 && index <= handlerStack.count, !isInQueue(song: song) else { return }
        
        let handler = StreamHandler(song: song, byteOffset: byteOffset, secondsOffset: secondsOffset, tempCache: tempCache, delegate: self)
        handlerStack.insert(handler, at: index)
        if handlerStack.count == 1 && startDownload {
            start(handler: handler)
        }
        
        // Download the lyrics
        if handler.song.tagArtistName != nil && handler.song.title.count > 0 {
            if !store.isLyricsCached(song: handler.song) {
                LyricsLoader(song: handler.song)?.startLoad()
            }
        }
        
        // Download the cover art
        if let coverArtId = song.coverArtId {
            _ = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: true).downloadArtIfNotExists()
            _ = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: false).downloadArtIfNotExists()
        }
        
        // Download the TagArtist to ensure it exists for the Downloads tab
        if song.tagArtistId > 0, !store.isTagArtistCached(serverId: song.serverId, id: song.tagArtistId) {
            TagArtistLoader(serverId: song.serverId, tagArtistId: song.tagArtistId).startLoad()
        }
        
        // Download the TagAlbum to ensure it's songs exist when offline if opening the tag album from the song in the Downloads tab
        // NOTE: The TagAlbum itself will be downloaded by the TagArtistLoader, but not the songs, so we need to make this second request
        if song.tagAlbumId > 0, (!store.isTagAlbumCached(serverId: song.serverId, id: song.tagAlbumId) || !store.isTagAlbumSongsCached(serverId: song.serverId, id: song.tagAlbumId)) {
            TagAlbumLoader(serverId: song.serverId, tagAlbumId: song.tagAlbumId).startLoad()
        }
        
        saveHandlerStack()
    }
    
    func queueStream(song: Song, tempCache: Bool, startDownload: Bool) {
        queueStream(song: song, index: handlerStack.count, tempCache: tempCache, startDownload: startDownload)
    }
    
    func fillStreamQueue(startDownload: Bool) {
        guard !settings.isJukeboxEnabled, !settings.isOfflineMode else { return }
        
        let numStreamsToQueue = settings.isSongCachingEnabled && settings.isNextSongCacheEnabled ? defaultNumberOfStreamsToQueue : 1
        guard handlerStack.count < numStreamsToQueue else { return }
        
        for i in 0..<numStreamsToQueue {
            if let song = playQueue.song(index: playQueue.indexFromCurrentIndex(offset: i)), !song.isVideo, !song.isFullyCached, !isInQueue(song: song) {
                var isLastTempCachedSong = false
                if let lastTempCachedSong = lastTempCachedSong, lastTempCachedSong == song {
                    isLastTempCachedSong = true
                }
                
                var isCurrentQueuedSong = false
                if let currentQueuedSong = cacheQueue.currentQueuedSong, currentQueuedSong == song {
                    isCurrentQueuedSong = true
                }
                
                if !isLastTempCachedSong && !isCurrentQueuedSong {
                    queueStream(song: song, tempCache: !settings.isSongCachingEnabled, startDownload: startDownload)
                }
            }
        }
        
        DDLogInfo("[StreamManager] fillStreamQueue: handlerStack: \(handlerStack)")
    }
    
    @objc func fillStreamQueue() {
        fillStreamQueue(startDownload: true)
    }
    
    @objc func songCachingToggled() {
        if settings.isSongCachingEnabled {
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(fillStreamQueue as () -> Void), name: Notifications.songPlaybackEnded)
        } else {
            NotificationCenter.removeObserverOnMainThread(self, name: Notifications.songPlaybackEnded)
        }
    }
    
    @objc func currentPlaylistIndexChanged() {
        // TODO: implement this
        // TODO: Fix this logic, it's wrong
        if let prevSong = playQueue.prevSong {
            removeStream(song: prevSong)
        }
    }
    
    @objc func currentPlaylistOrderChanged() {
        var songs = [Song]()
        if let currentSong = playQueue.currentSong {
            songs.append(currentSong)
        }
        if let nextSong = playQueue.nextSong {
            songs.append(nextSong)
        }
        
        removeAllStreams(except: songs)
        fillStreamQueue(startDownload: player.isStarted)
    }
    
    @objc func songPlaybackEnded() {
        if settings.isSongCachingEnabled {
            fillStreamQueue()
        }
    }
}

extension StreamManager: StreamHandlerDelegate {
    func streamHandlerStarted(handler: StreamHandler) {
        if handler.isTempCache {
            lastTempCachedSong = nil
        }
    }
    
    func streamHandlerStartPlayback(handler: StreamHandler) {
        lastCachedSong = handler.song
        player.streamReadyToStartPlayback(handler: handler)
        
        // TODO: Is this needed? Are we actually changing the stack?
        // I guess this is to save the isDelegateNotifiedToStartPlayback property?
        saveHandlerStack()
    }
    
    func streamHandlerConnectionFinished(handler: StreamHandler) {
        var success = true
        
        if handler.totalBytesTransferred == 0 {
            // Not a trial issue, but no data was returned at all
            let message = "We asked for a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed."
            let alert = UIAlertController(title: "Uh Oh!", message: message, preferredStyle: .alert)
            alert.addOKAction()
            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            
            // TODO: Do we care if this fails? Can the file potentially not be there at all?
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: handler.filePath))
            success = false
        } else if handler.totalBytesTransferred < 1000 {
            // Verify that it's a license issue
            if let data = try? Data(contentsOf: URL(fileURLWithPath: handler.filePath)) {
                let root = RXMLElement(fromXMLData: data)
                if root.isValid {
                    if let error = root.child("error"), error.isValid {
                        let subsonicError = SubsonicError(element: error)
                        if case .trialExpired = subsonicError {
                            let alert = UIAlertController(title: "Subsonic Error", message: subsonicError.localizedDescription, preferredStyle: .alert)
                            alert.addOKAction()
                            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                            
                            // TODO: Do we care if this fails? Can the file potentially not be there at all?
                            try? FileManager.default.removeItem(at: URL(fileURLWithPath: handler.filePath))
                            success = false
                        }
                    }
                }
            }
        }
        
        guard success else { return }
        
        // TODO: Should check store return values and do some extra error handling?
        if !handler.isTempCache {
            if cacheQueue.isInQueue(song: handler.song) {
                _ = store.removeFromDownloadQueue(song: handler.song)
            }
            DDLogInfo("[StreamManager] Marking download finished for \(handler.song)")
            _ = store.update(downloadFinished: true, song: handler.song)
        }
        
        lastCachedSong = handler.song
        if handler.isTempCache {
            lastTempCachedSong = handler.song
        }
        
        removeStream(handler: handler)
        
        if let handler = handlerStack.first {
            start(handler: handler)
        }
        
        fillStreamQueue()
        NotificationCenter.postOnMainThread(name: Notifications.streamHandlerSongDownloaded, userInfo: ["songId": handler.song.id])
    }
    
    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error) {
        if handler.numberOfReconnects < maxNumberOfReconnects {
            // Less than max number of reconnections, so try again
            handler.numberOfReconnects += 1
            // Retry connection after a delay to prevent a tight loop
            perform(#selector(resume(handler:)), with: handler, afterDelay: 1.5)
        } else {
            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.streamHandlerSongFailed)
            removeStream(handler: handler)
        }
    }
}
