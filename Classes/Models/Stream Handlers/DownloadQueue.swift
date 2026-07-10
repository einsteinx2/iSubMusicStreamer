//
//  DownloadQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/22/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift
import ProgressHUD

final class DownloadQueue {
    @LazyInjected private var store: Store
    @LazyInjected private var settings: SavedSettings
    @LazyInjected private var downloadsManager: DownloadsManager
    @LazyInjected private var streamManager: StreamManaging
    @LazyInjected private var metadataDownloader: SongMetadataDownloading
    @LazyInjected private var networkStatus: NetworkStatus

    private let maxNumberOfReconnects = 5
    
    private(set) var isDownloading = false
    private(set) var currentQueuedSong: Song?
    private(set) var currentStreamHandler: StreamHandler?
    
    var currentQueuedSongInDb: Song? {
        return store.firstSongInDownloadQueue()
    }
    
    init() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOnlineMode), name: Notifications.didEnterOnlineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOfflineMode), name: Notifications.didEnterOfflineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(manualCachingOnWWANSettingChanged), name: Notifications.manualCachingOnWWANSettingChanged)
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
        if settings.isOfflineMode || (!networkStatus.isWifi && !settings.isManualCachingOnWWANEnabled) {
            return
        }
        
        DDLogInfo("[DownloadQueue] starting download queue for \(song)")
        
        // For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
        if downloadsManager.freeSpace <= 25 * 1024 * 1024 {
            DDLogWarn("[DownloadQueue] Halting download queue: less than 25MB of free space")
            DispatchQueue.main.async {
                self.downloadsManager.showNoFreeSpaceMessage()
            }
            return
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
            DDLogInfo("[DownloadQueue] Marking \(song) as downloaded because it's already fully cached")
            
            // The song is fully cached, so delete it from the cache queue database
            _ = store.removeFromDownloadQueue(song: song)
            
            // Notify any tables
            NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongDownloaded, userInfo: ["songId": song.id])
            
            // Continue the queue
            DispatchQueue.main.async {
                self.start()
            }
            return
        }
        
        isDownloading = true
        
        // Create the stream handler
        if let handler = streamManager.handler(song: song) {
            DDLogInfo("[DownloadQueue] stealing \(song) from stream manager")
            
            // It's in the stream queue so steal the handler
            currentStreamHandler = handler
            handler.delegate = self
            streamManager.stealForDownloadQueue(handler: handler)
            if !handler.isDownloading {
                handler.start(resume: true)
            }
        } else {
            DDLogInfo("[DownloadQueue] creating download handler for \(song)")
            let handler = StreamHandler(song: song, tempCache: false, delegate: self)
            currentStreamHandler = handler
            handler.start()
        }
        
        metadataDownloader.downloadMetadata(song: song)

        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueStarted)
    }
    
    // TODO: implement this - why did this take a byteOffset if it didn't use it?
    func resume(byteOffset: Int) {
        guard let currentStreamHandler = currentStreamHandler, !settings.isOfflineMode else { return }
        currentStreamHandler.start(resume: true)
    }
    
    func stop() {
        guard isDownloading else { return }
        
        isDownloading = false
        currentStreamHandler?.cancel()
        currentStreamHandler = nil
        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueStopped)
    }
    
    func removeCurrentSong() -> Bool {
        guard let song = currentQueuedSong else { return false }
        
        stop()
        if store.removeFromDownloadQueue(song: song) {
            start()
            return true
        }
        return false
    }
    
    func clear() -> Bool {
        stop()
        return store.clearDownloadQueue()
    }
    
    // MARK: Notifications
    
    @objc private func didEnterOnlineMode() {
        if networkStatus.isWifi || settings.isManualCachingOnWWANEnabled {
            start()
        } else {
            stop()
        }
    }
    
    @objc private func didEnterOfflineMode() {
        stop()
    }

    @objc private func manualCachingOnWWANSettingChanged() {
        if !networkStatus.isWifi {
            settings.isManualCachingOnWWANEnabled ? start() : stop()
        }
    }
}

extension DownloadQueue: StreamHandlerDelegate {
    func streamHandlerStarted(handler: StreamHandler) {
        // Do nothing here (handled in StreamManager only)
    }
    
    func streamHandlerStartPlayback(handler: StreamHandler) {
        streamManager.streamHandlerStartPlayback(handler: handler)
    }
    
    func streamHandlerConnectionFinished(handler: StreamHandler) {
        guard handler.validateFinishedDownload() else {
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
        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongDownloaded, userInfo: ["songId": handler.song.id])
        
        // Download the next song in the queue
        isDownloading = false
        start()
    }
    
    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error) {
        if handler.numberOfReconnects < maxNumberOfReconnects {
            // Less than max number of reconnections, so try again
            handler.numberOfReconnects += 1
            // Retry connection after a delay to prevent a tight loop. Only resume if
            // the failed handler is still the active one, so a stale retry can never
            // restart a replacement handler
            DispatchQueue.main.async(after: 1.5) { [weak self] in
                guard let self, self.currentStreamHandler == handler else { return }
                self.resume(byteOffset: 0)
            }
        } else {
            ProgressHUD.banner("Song failed to download", handler.song.primaryLabelText)
            
            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongFailed)
            _ = store.removeFromDownloadQueue(song: handler.song)
            currentStreamHandler = nil
            start()
        }
    }
}

// Abstraction over the download queue so consumers can be unit tested with a fake
// (registered in DependencyInjection.swift)
protocol DownloadQueueing: AnyObject {
    var isDownloading: Bool { get }
    var currentQueuedSong: Song? { get }
    var currentStreamHandler: StreamHandler? { get }
    func isInQueue(song: Song) -> Bool
    func start()
    func stop()
    @discardableResult func removeCurrentSong() -> Bool
    @discardableResult func clear() -> Bool
}

extension DownloadQueue: DownloadQueueing {}
