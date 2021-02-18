//
//  CacheQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/22/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

final class CacheQueue {
    @LazyInjected private var store: Store
    @LazyInjected private var settings: Settings
    @LazyInjected private var cache: Cache
    @LazyInjected private var streamManager: StreamManager
    
    private let maxNumberOfReconnects = 5
    
    private(set) var isDownloading = false
    private(set) var currentQueuedSong: Song?
    private(set) var currentStreamHandler: StreamHandler?
    
    var currentQueuedSongInDb: Song? {
        return store.firstSongInDownloadQueue()
    }
    
    func isInQueue(song: Song) -> Bool {
        return store.isSongInDownloadQueue(song: song)
    }
    
    // TODO: implement this - check return values from store operations
    func start() {
        guard !isDownloading else { return }
        
        currentQueuedSong = currentQueuedSongInDb
        guard let song = currentQueuedSongInDb else { return }
        
        // Check if there's another queued song and that were are on Wifi
        if settings.isOfflineMode || (!AppDelegate.shared.isWifi && !settings.isManualCachingOnWWANEnabled) {
            return
        }
        
        DDLogInfo("[CacheQueue] starting download queue for \(song)")
        
        // For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
        if cache.freeSpace <= 25 * 1024 * 1024 {
            /*[EX2Dispatch runInMainThread:^
             {
                 [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot download any more music. Please free some space and try again", @"Download manager, device out of space message")];
             }];*/
            
            return;
        }
        
        // Check if this is a video
        if song.isVideo {
            // Remove from the queue
            _ = store.removeFromDownloadQueue(song: song)
            
            // Continue the queue
            start()
            return
        }
        
        // Check if the song is fully cached and if so, remove it from the queue and return
        if song.isFullyCached {
            DDLogInfo("[CacheQueue] Marking \(song) as downloaded because it's already fully cached")
            
            // The song is fully cached, so delete it from the cache queue database
            _ = store.removeFromDownloadQueue(song: song)
            
            // Notify any tables
            NotificationCenter.postOnMainThread(name: Notifications.cacheQueueSongDownloaded, userInfo: ["songId": song.id])
            
            // Continue the queue
            DispatchQueue.main.async {
                self.start()
            }
            return
        }
        
        isDownloading = true
        
        // TODO: implement this (queue the 5 loaders so that they execute sequentially)
        // TODO: implement this (share this logic between CacheQueue and StreamManager)
        
        // Download the lyrics
        if song.tagArtistName != nil && song.title.count > 0 {
            if !store.isLyricsCached(song: song) {
                LyricsLoader(song: song)?.startLoad()
            }
        }
        
        // Download the cover art
        if let coverArtId = song.coverArtId {
            _ = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: true).downloadArtIfNotExists()
            _ = CoverArtLoader(serverId: song.serverId, coverArtId: coverArtId, isLarge: false).downloadArtIfNotExists()
        }
        
        // Download the TagArtist to ensure it exists for the Downloads tab
        if let tagArtistId = song.tagArtistId, !store.isTagArtistCached(serverId: song.serverId, id: tagArtistId) {
            TagArtistLoader(serverId: song.serverId, tagArtistId: tagArtistId).startLoad()
        }
        
        // Download the TagAlbum to ensure it's songs exist when offline if opening the tag album from the song in the Downloads tab
        // NOTE: The TagAlbum itself will be downloaded by the TagArtistLoader, but not the songs, so we need to make this second request
        if let tagAlbumId = song.tagAlbumId, (!store.isTagAlbumCached(serverId: song.serverId, id: tagAlbumId) || !store.isTagAlbumSongsCached(serverId: song.serverId, id: tagAlbumId)) {
            TagAlbumLoader(serverId: song.serverId, tagAlbumId: tagAlbumId).startLoad()
        }
        
        // Create the stream handler
        if let handler = streamManager.handler(song: song) {
            DDLogInfo("[CacheQueue] stealing \(song) from stream manager")
            
            // It's in the stream queue so steal the handler
            currentStreamHandler = handler
            handler.delegate = self
            streamManager.stealForCacheQueue(handler: handler)
            if !handler.isDownloading {
                handler.start(resume: true)
            }
        } else {
            DDLogInfo("[CacheQueue] creating download handler for \(song)")
            let handler = StreamHandler(song: song, tempCache: false, delegate: self)
            currentStreamHandler = handler
            handler.start()
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.cacheQueueStarted)
    }
    
    // TODO: implement this - why did this take a byteOffset if it didn't use it?
    func resume(byteOffset: Int) {
        guard let currentStreamHandler = currentStreamHandler, !settings.isOfflineMode else { return }
        currentStreamHandler.start(resume: true)
    }
    
    func stop() {
        guard !isDownloading else { return }
        
        isDownloading = false
        currentStreamHandler?.cancel()
        currentStreamHandler = nil
        NotificationCenter.postOnMainThread(name: Notifications.cacheQueueStopped)
    }
    
    func removeCurrentSong() {
        guard let song = currentQueuedSong else { return }
        
        stop()
        _ = store.removeFromDownloadQueue(song: song)
        start()
    }
}

extension CacheQueue: StreamHandlerDelegate {
    func streamHandlerStarted(handler: StreamHandler) {
        // Do nothing here (handled in StreamManager only)
    }
    
    func streamHandlerStartPlayback(handler: StreamHandler) {
        streamManager.streamHandlerStartPlayback(handler: handler)
    }
    
    // TODO: implement this - share this logic with stream manager
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
        
        guard success else {
            stop()
            return
        }
        
        if let song = currentQueuedSong {
            // Mark song as cached
            _ = store.update(downloadFinished: true, song: song)
            
            // Remove the song from the cache queue
            _ = store.removeFromDownloadQueue(song: song)
            
            currentQueuedSong = nil
        }
    
        // Remove the stream handler
        currentStreamHandler = nil;
        
        // Tell the cache queue view to reload
        NotificationCenter.postOnMainThread(name: Notifications.cacheQueueSongDownloaded, userInfo: ["songId": handler.song.id])
        
        // Download the next song in the queue
        isDownloading = false
        start()
    }
    
    // TODO: implement this - share this logic with stream manager
    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error) {
        if handler.numberOfReconnects < maxNumberOfReconnects {
            // Less than max number of reconnections, so try again
            handler.numberOfReconnects += 1
            // Retry connection after a delay to prevent a tight loop
            DispatchQueue.main.async(after: 1.5) { [weak self] in
                self?.resume(byteOffset: 0)
            }
        } else {
            SlidingNotification.showOnMainWindow(message: "Song failed to download")
            
            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.cacheQueueSongFailed)
            _ = store.removeFromDownloadQueue(song: handler.song)
            currentStreamHandler = nil
            start()
        }
    }
}

@objc final class CacheQueue_ObjCDeleteMe: NSObject {
    private static var cacheQueue: CacheQueue { Resolver.resolve() }
    
    @objc static func start() {
        cacheQueue.start()
    }
    
    @objc static func stop() {
        cacheQueue.stop()
    }
}
