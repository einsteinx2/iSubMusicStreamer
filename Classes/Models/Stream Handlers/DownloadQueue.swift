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
    @LazyInjected private var streamManager: StreamManager
    
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
        if settings.isOfflineMode || (!SceneDelegate.shared.isWifi && !settings.isManualCachingOnWWANEnabled) {
            return
        }
        
        DDLogInfo("[DownloadQueue] starting download queue for \(song)")
        
        // For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
        if downloadsManager.freeSpace <= 25 * 1024 * 1024 {
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
        
        SongsHelper.downloadMetadata(song: song)
        
        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueStarted)
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
        if SceneDelegate.shared.isWifi || settings.isManualCachingOnWWANEnabled {
            start()
        } else {
            stop()
        }
    }
    
    @objc private func didEnterOfflineMode() {
        stop()
    }
}

extension DownloadQueue: StreamHandlerDelegate {
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
                let root = RXMLElement(xmlData: data)
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
        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongDownloaded, userInfo: ["songId": handler.song.id])
        
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
            ProgressHUD.banner("Song failed to download", handler.song.primaryLabelText)
            
            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongFailed)
            _ = store.removeFromDownloadQueue(song: handler.song)
            currentStreamHandler = nil
            start()
        }
    }
}
