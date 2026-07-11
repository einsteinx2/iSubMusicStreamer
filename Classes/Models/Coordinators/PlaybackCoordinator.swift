//
//  PlaybackCoordinator.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// The playback facade (Phase 8.4): the only type UI code and services call to start,
// stop, or reorganize playback. In this phase every queue-orchestration method
// forwards to the existing PlayQueue implementation; Phase 8.7 moves those bodies
// here and reduces PlayQueue to queue math + Store persistence, and Phase 8.8
// dissolves the jukebox-vs-local branches behind the PlaybackMode strategy.
final class PlaybackCoordinator: NSObject {
    private let queue: PlayQueue
    private let settings: SavedSettings
    private let store: Store
    private let player: PlayerControlling
    private let jukebox: Jukebox
    private let streamManager: StreamManaging
    private let downloadQueue: DownloadQueueing

    // The full dependency set arrives now even though the facade barely uses it, so
    // the composition root and tests wire this constructor exactly once
    init(queue: PlayQueue, settings: SavedSettings, store: Store, player: PlayerControlling,
         jukebox: Jukebox, streamManager: StreamManaging, downloadQueue: DownloadQueueing) {
        self.queue = queue
        self.settings = settings
        self.store = store
        self.player = player
        self.jukebox = jukebox
        self.streamManager = streamManager
        self.downloadQueue = downloadQueue
        super.init()
    }

    // MARK: Transport / orchestration (forwarding until Phase 8.7)

    @discardableResult
    func play(position: Int) -> Song? {
        queue.playSong(position: position)
    }

    @discardableResult
    func playNext() -> Song? {
        queue.playNextSong()
    }

    @discardableResult
    func playPrevious() -> Song? {
        queue.playPrevSong()
    }

    @discardableResult
    func playCurrent() -> Song? {
        queue.playCurrentSong()
    }

    @discardableResult
    func resumeSong() -> Song? {
        queue.resumeSong()
    }

    func startSong() {
        queue.startSong()
    }

    func startSong(byteOffset: Int, secondsOffset: Double) {
        queue.startSong(offsetInBytes: byteOffset, offsetInSeconds: secondsOffset)
    }

    func shuffleToggle() {
        queue.shuffleToggle()
    }

    @discardableResult
    func moveSong(fromIndex: Int, toIndex: Int) -> Bool {
        queue.moveSong(fromIndex: fromIndex, toIndex: toIndex)
    }

    @discardableResult
    func removeSongs(indexes: [Int]) -> Bool {
        queue.removeSongs(indexes: indexes)
    }

    // MARK: Queue-changed hooks (moved from AsyncSongsHelper, minus its notification posts)

    // Clears the live queue before a play-all/shuffle-all replaces it
    func prepareForPlayAll() {
        if settings.isJukeboxEnabled {
            jukebox.clearPlaylist()
        } else {
            _ = store.clearPlayQueue()
        }
        queue.isShuffle = false
    }

    // The queue contents changed (songs appended/inserted): sync the remote playlist
    // in jukebox mode, or top up the stream queue locally
    func queueDidChange() {
        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        } else {
            streamManager.fillStreamQueue(startDownload: player.isStarted)
        }
    }
}
