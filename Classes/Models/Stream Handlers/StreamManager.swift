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
    @LazyInjected private var player: BassGaplessPlayer
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: StreamManager { Resolver.resolve() }
    
    private let defaultNumberOfStreamsToQueue = 2
    private let maxNumberOfReconnects = 5
    
    private var handlerStack = [ISMSAbstractStreamHandler]()
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
                        handler.start(true)
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
        guard isQueueDownloading else { return nil }
        return handlerStack.first?.mySong
    }
    
    var firstHandlerInQueue: ISMSAbstractStreamHandler? {
        return handlerStack.first
    }
    
    @objc func handler(song: Song) -> ISMSAbstractStreamHandler? {
        return handlerStack.first { $0.mySong.isEqual(song) }
    }
    
    func isFirstInQueue(song: Song) -> Bool {
        if let firstSong = handlerStack.first?.mySong {
            return firstSong.isEqual(song)
        }
        return false
    }
    
    func isInQueue(song: Song) -> Bool {
        return handlerStack.contains(where: { $0.mySong.isEqual(song) })
    }
    
    func isDownloading(song: Song) -> Bool {
        return handler(song: song)?.isDownloading ?? false
    }
    
    var isQueueDownloading: Bool {
        for handler in handlerStack {
            if handler.isDownloading {
                return true
            }
        }
        return false
    }
    
    func cancelAllStreams(except handlers: [ISMSAbstractStreamHandler]) {
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
        if let handler = handler(song: song) {
            cancelAllStreams(except: [handler])
        }
    }
    
    func cancelAllStreams() {
        cancelAllStreams(except: [] as [ISMSAbstractStreamHandler])
    }
    
    func cancelStream(handler: ISMSAbstractStreamHandler) {
        cancelResume(handler: handler)
        handler.cancel()
        saveHandlerStack()
    }
    
    func cancelStream(index: Int) {
        guard index < handlerStack.count else { return }
        cancelStream(handler: handlerStack[index])
    }
    
    func cancelStream(song: Song) {
        if let handler = handlerStack.first(where: { $0.mySong.isEqual(song) }) {
            cancelStream(handler: handler)
        }
    }
    
    private func removeStreamWithoutSavingStack(handler: ISMSAbstractStreamHandler) {
        // Cancel the handler
        cancelResume(handler: handler)
        handler.cancel()
        
        // Remove the handler
        handlerStack.removeAll { $0.isEqual(handler) }
        
        // Remove the song from downloads if necessary
        let song = handler.mySong
        let isCurrentQueuedSong = cacheQueue.currentQueuedSong?.isEqual(song) ?? false
        // TODO: Why is this checking if the CacheQueue is downloading?
        if !isCurrentQueuedSong && !song.isFullyCached && !song.isTempCached && cacheQueue.isQueueDownloading {
            DDLogInfo("[StreamManager] Removing song from cached songs table: \(song)")
            _ = song.removeFromDownloads()
        }
    }
    
    func removeAllStreams(except handlers: [ISMSAbstractStreamHandler]) {
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
        if let handler = handler(song: song) {
            removeAllStreams(except: [handler])
        }
    }
    
    @objc func removeAllStreams() {
        removeAllStreams(except: [] as [ISMSAbstractStreamHandler])
    }
    
    func removeStream(handler: ISMSAbstractStreamHandler) {
        // Remove the handler
        removeStreamWithoutSavingStack(handler: handler)
        
        // Start the next handler
        if let handler = handlerStack.first, !handler.isDownloading {
            handler.start()
        }
        
        saveHandlerStack()
    }
    
    func removeStream(index: Int) {
        guard index < handlerStack.count else { return }
        removeStream(handler: handlerStack[index])
    }
    
    func removeStream(song: Song) {
        if let handler = handlerStack.first(where: { $0.mySong.isEqual(song) }) {
            removeStream(handler: handler)
        }
    }
    
    private func cancelResume(handler: ISMSAbstractStreamHandler) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resume(handler:)), object: handler)
    }
    
    @objc func resume(handler: ISMSAbstractStreamHandler) {
        // As an added check, verify that this handler is still in the stack
        guard isInQueue(song: handler.mySong) else { return }
        
        let isCurrentQueuedSong = cacheQueue.currentQueuedSong?.isEqual(handler.mySong) ?? false
        if cacheQueue.isQueueDownloading && isCurrentQueuedSong {
            // This song is already being downloaded by the cache queue, so just start the player
            ismsStreamHandlerStartPlayback(handler)
            
            // Remove the handler from the stack
            removeStream(handler: handler)
            
            // Start the next handler which is now the first object
            if let handler = handlerStack.first, !handler.isDownloading {
                handler.start()
            }
        } else {
            handler.start(true)
        }
    }
    
    func resumeQueue() {
        if let handler = handlerStack.first {
            resume(handler: handler)
        }
    }
    
    func start(handler: ISMSAbstractStreamHandler, resume: Bool) {
        // As an added check, verify that this handler is still in the stack
        guard isInQueue(song: handler.mySong) else { return }
        
        DDLogInfo("[StreamManager] starting handler \(handler) resume: \(resume), handlerStack: \(handlerStack)")
        
        let isCurrentQueuedSong = cacheQueue.currentQueuedSong?.isEqual(handler.mySong) ?? false
        if cacheQueue.isQueueDownloading && isCurrentQueuedSong {
            // This song is already being downloaded by the cache queue, so just start the player
            ismsStreamHandlerStartPlayback(handler)
            
            // Remove the handler from the stack
            removeStream(handler: handler)
            
            // Start the next handler which is now the first object
            if let handler = handlerStack.first, !handler.isDownloading {
                handler.start()
            }
        } else {
            handler.start(resume)
            let title = handler.mySong.title
            if let tagArtistName = handler.mySong.tagArtistName, title.count > 0 {
                if !store.isLyricsCached(tagArtistName: tagArtistName, songTitle: title) {
                    LyricsLoader(serverId: handler.mySong.serverId, tagArtistName: tagArtistName, songTitle: title).startLoad()
                }
            }
        }
    }
    
    func start(handler: ISMSAbstractStreamHandler) {
        start(handler: handler, resume: false)
    }
    
    private let handlerStackKey = "handlerStack"
    
    func saveHandlerStack() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: handlerStack, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: handlerStackKey)
            UserDefaults.standard.synchronize()
        } catch {
            DDLogError("[StreamManager] saveHandlerStack: failed to archive handler stack \(error)")
        }
    }
    
    func loadHandlerStack() {
        do {
            if let data = UserDefaults.standard.object(forKey: handlerStackKey) as? Data {
                handlerStack = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, ISMSAbstractStreamHandler.self], from: data) as? [ISMSAbstractStreamHandler] ?? []
            }
        
            for handler in handlerStack {
                handler.delegate = self
            }
            
            DDLogInfo("[StreamManager] loaded handler stack \(handlerStack)")
        } catch {
            DDLogError("[StreamManager] saveHandlerStack: failed to unarchive handler stack \(error)")
        }
    }
    
    // MARK: Handler Stealing
    
    @objc func stealForCacheQueue(handler: ISMSAbstractStreamHandler) {
        DDLogInfo("[StreamManager] cache queue manager stole handler for song \(handler.mySong)")
        handler.partialPrecacheSleep = false
        handlerStack.removeAll { $0.isEqual(handler) }
        saveHandlerStack()
        fillStreamQueue()
    }
    
    // MARK: Download
    
    // TODO: implement this (queue the 4 loaders so that they execute sequentially)
    func queueStream(song: Song, byteOffset: UInt64 = 0, secondsOffset: Double = 0.0, index: Int, tempCache: Bool, startDownload: Bool) {
        guard index <= handlerStack.count, !isInQueue(song: song) else { return }
        
        let handler = ISMSNSURLSessionStreamHandler(song: song, byteOffset: byteOffset, secondsOffset: secondsOffset, isTemp: tempCache, delegate: self)
        handlerStack.insert(handler, at: index)
        if handlerStack.count == 1 && startDownload {
            start(handler: handler)
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
                if let lastTempCachedSong = lastTempCachedSong, !lastTempCachedSong.isEqual(song) {
                    isLastTempCachedSong = true
                }
                
                var isCurrentQueuedSong = false
                if let currentQueuedSong = cacheQueue.currentQueuedSong, !currentQueuedSong.isEqual(song) {
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

@objc extension StreamManager: ISMSStreamHandlerDelegate {
    func ismsStreamHandlerStarted(_ handler: ISMSAbstractStreamHandler) {
        if handler.isTempCache {
            lastTempCachedSong = nil
        }
    }
    
    func ismsStreamHandlerStartPlayback(_ handler: ISMSAbstractStreamHandler) {
        lastCachedSong = handler.mySong
        
        if let currentSong = playQueue.currentSong, handler.mySong.isEqual(currentSong) {
            player.startNewSong(currentSong, at: UInt(playQueue.currentIndex), withOffsetInBytes: NSNumber(value: handler.byteOffset), orSeconds: NSNumber(value: handler.secondsOffset))
        }
        
        // TODO: Is this needed? Are we actually changing the stack?
        saveHandlerStack()
    }
    
    func ismsStreamHandlerConnectionFinished(_ handler: ISMSAbstractStreamHandler) {
        var success = true
        
        if handler.totalBytesTransferred == 0 {
            // Not a trial issue, but no data was returned at all
            let message = "We asked for a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed."
            let alert = UIAlertController(title: "Uh Oh!", message: message, preferredStyle: .alert)
            alert.addCancelAction(title: "OK")
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
                        let code = error.attribute("code").intXML
                        // TODO: implement this - Make an enum of Subsonic error codes
                        if code == 60 {
                            // This is a trial period message, alert the user and stop streaming
                            let message = "You can purchase a license for Subsonic by logging in to the web interface and clicking the red Donate link on the top right.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.\n\nThere are 100% free and open source compatible alternatives such as AirSonic if you're not interested in purchasing a Subsonic license."
                            let alert = UIAlertController(title: "Subsonic API Trial Expired", message: message, preferredStyle: .alert)
                            alert.addCancelAction(title: "OK")
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
            if cacheQueue.isSong(inQueue: handler.mySong) {
                _ = store.removeFromDownloadQueue(song: handler.mySong)
            }
            DDLogInfo("[StreamManager] Marking download finished for \(handler.mySong)")
            _ = store.update(downloadFinished: true, song: handler.mySong)
        }
        
        lastCachedSong = handler.mySong
        if handler.isTempCache {
            lastTempCachedSong = handler.mySong
        }
        
        removeStream(handler: handler)
        
        if let handler = handlerStack.first {
            start(handler: handler)
        }
        
        fillStreamQueue()
        NotificationCenter.postOnMainThread(name: Notifications.streamHandlerSongDownloaded, object: nil, userInfo: ["songId": handler.mySong.id])
    }
    
    func ismsStreamHandlerConnectionFailed(_ handler: ISMSAbstractStreamHandler, withError error: Error?) {
        if handler.numOfReconnects < maxNumberOfReconnects {
            // Less than max number of reconnections, so try again
            handler.numOfReconnects += 1
            // Retry connection after a delay to prevent a tight loop
            perform(#selector(resume(handler:)), with: handler, afterDelay: 1.5)
        } else {
            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.streamHandlerSongFailed)
            removeStream(handler: handler)
        }
    }
}
