//
//  DownloadEngine.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// The single owner of the download subsystem (Phase 8.10): the stream manager is
// the temp/prefetch lane, and the permanent download lane (the old DownloadQueue
// type) lives directly in this engine. The old cross-object handler "steal" — a
// delegate flip in DownloadQueue.start() paired with a stack removal in
// StreamManager.stealForDownloadQueue(), held together by convention — is now an
// internal atomic transfer: promote(handler:) flips the delegate to this engine and
// removes it from the stream lane's stack in one place.
final class DownloadEngine {
    let streamManager: StreamManager

    private let store: Store
    private let settings: SavedSettings
    private let downloadsManager: DownloadsManager
    private let player: PlayerControlling
    private let networkStatus: NetworkStatus
    private let metadataDownloader: SongMetadataDownloading

    private let maxNumberOfReconnects = 5

    // MARK: Permanent download lane state (the old DownloadQueue)

    private(set) var isDownloading = false
    private(set) var currentQueuedSong: Song?
    private(set) var currentStreamHandler: StreamHandler?

    var currentQueuedSongInDb: Song? {
        return store.firstSongInDownloadQueue()
    }

    init(store: Store, settings: SavedSettings, downloadsManager: DownloadsManager,
         player: PlayerControlling, networkStatus: NetworkStatus,
         metadataDownloader: SongMetadataDownloading) {
        self.store = store
        self.settings = settings
        self.downloadsManager = downloadsManager
        self.player = player
        self.networkStatus = networkStatus
        self.metadataDownloader = metadataDownloader
        streamManager = StreamManager(store: store,
                                      settings: settings,
                                      player: player,
                                      downloadsManager: downloadsManager,
                                      networkStatus: networkStatus,
                                      metadataDownloader: metadataDownloader)
        // The stream lane consults the permanent lane's read-only status before
        // deleting partial downloads or filling its queue
        streamManager.attach(downloadQueue: self)

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOnlineMode), name: Notifications.didEnterOnlineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOfflineMode), name: Notifications.didEnterOfflineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(manualCachingOnWWANSettingChanged), name: Notifications.manualCachingOnWWANSettingChanged)
    }

    func attach(playQueue: PlayQueue) {
        streamManager.attach(playQueue: playQueue)
    }

    // Restores the persisted handler stack and resumes interrupted downloads
    func setup() {
        streamManager.setup()
    }

    // The handler's dependencies are this engine's own dependencies
    private var handlerDependencies: StreamHandler.Dependencies {
        StreamHandler.Dependencies(downloadsManager: downloadsManager, settings: settings, store: store, player: player, networkStatus: networkStatus)
    }

    // The atomic lane transfer that replaces the old steal: the delegate flip and
    // the stream-stack removal can no longer be separated
    private func promote(handler: StreamHandler) {
        currentStreamHandler = handler
        handler.delegate = self
        streamManager.removeFromStack(handler: handler)
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

        DDLogInfo("[DownloadEngine] starting download queue for \(song)")

        // For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
        if downloadsManager.freeSpace <= 25 * 1024 * 1024 {
            DDLogWarn("[DownloadEngine] Halting download queue: less than 25MB of free space")
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
            DDLogInfo("[DownloadEngine] Marking \(song) as downloaded because it's already fully cached")

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
            DDLogInfo("[DownloadEngine] promoting \(song) from the stream lane")

            // It's in the stream queue, so transfer it to the permanent lane
            promote(handler: handler)
            if !handler.isDownloading {
                handler.start(resume: true)
            }
        } else {
            DDLogInfo("[DownloadEngine] creating download handler for \(song)")
            let handler = StreamHandler(song: song, tempCache: false, delegate: self, dependencies: handlerDependencies)
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

// The permanent lane is its own handler delegate (the stream lane's handlers keep
// StreamManager as theirs) — the engine is the only type that ever reassigns a
// handler between the two
extension DownloadEngine: StreamHandlerDelegate {
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
            HUD.banner("Song failed to download", handler.song.primaryLabelText)

            // Tried max number of times so remove
            NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongFailed)
            _ = store.removeFromDownloadQueue(song: handler.song)
            currentStreamHandler = nil

            // Move on to the next queued song; without resetting isDownloading the
            // guard in start() makes this (and every later) start() a no-op and the
            // download queue stalls until an offline/online cycle or relaunch
            isDownloading = false
            start()
        }
    }
}

// Read-only view of the permanent download lane for services that only need to ask
// what is currently downloading (the stream lane holds this as a weak back-reference)
protocol DownloadQueueStatus: AnyObject {
    var isDownloading: Bool { get }
    var currentQueuedSong: Song? { get }
    func isInQueue(song: Song) -> Bool
}

// Abstraction over the permanent download lane so consumers can be unit tested with
// a fake (registered in DependencyInjection.swift)
protocol DownloadQueueing: DownloadQueueStatus {
    var currentStreamHandler: StreamHandler? { get }
    func start()
    func stop()
    @discardableResult func removeCurrentSong() -> Bool
    @discardableResult func clear() -> Bool
}

extension DownloadEngine: DownloadQueueing {}
