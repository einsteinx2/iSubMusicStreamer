//
//  PlaybackCoordinator.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// The playback facade (Phase 8.4/8.7): the only type UI code and services call to
// start, stop, or reorganize playback. Owns the orchestration that used to live in
// PlayQueue (which is now queue math + Store persistence); Phase 8.8 dissolves the
// jukebox-vs-local branches here behind the PlaybackMode strategy.
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

        // Mode-switch side effects run from these observers regardless of who flipped
        // the setting (setJukeboxEnabled below, the jukebox's auth-error self-disable,
        // or SceneDelegate's offline disable); both mode hooks are idempotent
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxWasEnabled), name: Notifications.jukeboxEnabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxWasDisabled), name: Notifications.jukeboxDisabled)

        localMode = LocalPlaybackMode(player: player, streamManager: streamManager, store: store, coordinator: self)
        jukeboxMode = JukeboxPlaybackMode(jukebox: jukebox, queue: queue, store: store, settings: settings)
        // The jukebox reports server state (index, mirrored queue) back through its
        // delegate — the jukebox mode this coordinator owns
        jukebox.attach(delegate: jukeboxMode)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    // MARK: Playback mode (jukebox vs local)

    private var localMode: LocalPlaybackMode!
    private var jukeboxMode: JukeboxPlaybackMode!
    // Computed from the setting so there is no duplicated mode state
    private var activeMode: PlaybackMode { settings.isJukeboxEnabled ? jukeboxMode : localMode }

    var isPlaying: Bool { activeMode.isPlaying }

    // The single place a jukebox-mode flip happens (aside from raw settings writes
    // that intentionally skip the side effects, e.g. server switching)
    func setJukeboxEnabled(_ enabled: Bool) {
        guard settings.isJukeboxEnabled != enabled else { return }
        settings.isJukeboxEnabled = enabled
        NotificationCenter.postOnMainThread(name: enabled ? Notifications.jukeboxEnabled : Notifications.jukeboxDisabled)
    }

    @objc private func jukeboxWasEnabled() {
        localMode.deactivate()
        jukeboxMode.activate()
    }

    @objc private func jukeboxWasDisabled() {
        jukeboxMode.deactivate()
        localMode.activate()
    }

    // MARK: Transport (dispatched to the active mode)

    @discardableResult
    func play() -> Bool {
        activeMode.play()
    }

    @discardableResult
    func pause() -> Bool {
        activeMode.pause()
    }

    @discardableResult
    func togglePlayPause() -> Bool {
        activeMode.togglePlayPause()
    }

    @discardableResult
    func stop() -> Bool {
        activeMode.stop()
    }

    @discardableResult
    func seek(seconds: Double) -> Bool {
        activeMode.seek(seconds: seconds)
    }

    // MARK: Transport / orchestration (bodies moved verbatim from PlayQueue in 8.7)

    @discardableResult
    func play(position: Int) -> Song? {
        queue.currentIndex = position
        guard let currentSong = queue.currentSong else { return nil }

        return DispatchQueue.mainSyncSafe {
            if !currentSong.isVideo {
                // Remove the video player if this is not a video
                NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)
            }

            if currentSong.isVideo && !activeMode.canPlayVideos {
                HUD.banner("Cannot play videos in Jukebox mode.", nil)
                return nil
            }

            activeMode.playSong(at: position, song: currentSong)
            return currentSong
        }
    }

    @discardableResult
    func playNext() -> Song? {
        DDLogVerbose("[PlaybackCoordinator] playNext called, calling play(position: \(queue.nextIndex))")
        return play(position: queue.nextIndex)
    }

    @discardableResult
    func playPrevious() -> Song? {
        DDLogVerbose("[PlaybackCoordinator] playPrevious called")
        if player.progress > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            DDLogVerbose("[PlaybackCoordinator] playPrevious past 10 seconds in the song, so restart playback instead of changing songs, calling play(position: \(queue.currentIndex))")
            return play(position: queue.currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            DDLogVerbose("[PlaybackCoordinator] playPrevious within first 10 seconds, so go to previous, calling play(position: \(queue.prevIndex))")
            return play(position: queue.prevIndex)
        }
    }

    @discardableResult
    func playCurrent() -> Song? {
        DDLogVerbose("[PlaybackCoordinator] playCurrent called, calling play(position: \(queue.currentIndex))")
        return play(position: queue.currentIndex)
    }

    // Resume song after iSub shuts down
    @discardableResult
    func resumeSong() -> Song? {
        if let currentSong = queue.currentSong, settings.isRecover {
            startSong(byteOffset: settings.byteOffset, secondsOffset: settings.seekTime)
            return currentSong
        } else {
            player.startByteOffset = settings.byteOffset
            player.startSecondsOffset = settings.seekTime
            return nil
        }
    }

    func startSong() {
        startSong(byteOffset: 0, secondsOffset: 0)
    }

    private var offsetInBytes = 0
    private var offsetInSeconds = 0.0
    func startSong(byteOffset: Int, secondsOffset: Double) {
        DispatchQueue.mainSyncSafe {
            // Destroy the streamer/video player to start a new song
            player.stop()
            NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)

            guard queue.currentSong != nil else { return }

            offsetInBytes = byteOffset
            offsetInSeconds = secondsOffset

            // Only start the caching process if it's been a half second after the last request. Prevents crash when skipping through playlist fast.
            // NOTE: perform(afterDelay:) schedules on the main run loop's default mode
            // only, so it coalesces and defers during scroll tracking — do not convert
            // to DispatchQueue.main.async(after:)
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startSongAtOffsetsInternal), object: nil)
            perform(#selector(startSongAtOffsetsInternal), with: nil, afterDelay: 1)
        }
    }

    @objc private func startSongAtOffsetsInternal() {
        guard let song = queue.currentSong else { return }
        let index = queue.currentIndex

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
            }
        } else if !song.isFullyCached && settings.isOfflineMode {
            playNext()
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

    /// Called when the shuffle button is pushed.
    func shuffleToggle() {
        if queue.isShuffle {
            if let shuffleCurrentSong = queue.currentSong {
                queue.isShuffle = false
                if let currentPosition = store.getSongPosition(localPlaylistId: LocalPlaylist.Default.playQueueId, songId: shuffleCurrentSong.id) {
                    queue.normalIndex = currentPosition
                    if let shuffleQueueCurrentSong = queue.song(index: currentPosition) {
                        streamManager.removeAllStreams(except: shuffleQueueCurrentSong)
                        streamManager.fillStreamQueue(startDownload: true)
                    }
                }
                didToggleShuffle()
            }
        } else {
            if store.createShuffleQueue(currentPosition: queue.normalIndex) {
                queue.shuffleIndex = 0
                queue.isShuffle = true
                // The playing song is at position 0 of the freshly created shuffle queue
                if let currentSong = queue.currentSong {
                    streamManager.removeAllStreams(except: currentSong)
                    streamManager.fillStreamQueue(startDownload: true)
                }
                didToggleShuffle()
            }
        }
    }

    private func didToggleShuffle() {
        activeMode.didToggleShuffle(currentIndex: queue.currentIndex)

        // Update the playlist views; NowPlayingService observes and informs the OS
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistShuffleToggled)
    }

    @discardableResult
    func moveSong(fromIndex: Int, toIndex: Int) -> Bool {
        if store.move(songAtPosition: fromIndex, toPosition: toIndex, localPlaylistId: queue.currentPlaylistId) {
            activeMode.syncRemoteQueueIfNeeded()

            // Correct the value of currentPlaylistPosition
            if fromIndex == queue.currentIndex {
                queue.currentIndex = toIndex
            } else if fromIndex < queue.currentIndex && toIndex >= queue.currentIndex {
                queue.currentIndex -= 1
            } else if fromIndex > queue.currentIndex && toIndex <= queue.currentIndex {
                queue.currentIndex += 1
            }
            return true
        }
        return false
    }

    @discardableResult
    func removeSongs(indexes: [Int]) -> Bool {
        if store.remove(songsAtPositions: indexes, localPlaylistId: queue.currentPlaylistId) {
            // Stop the player if we deleted the current song
            if indexes.contains(queue.currentIndex) {
                player.stop()
                queue.currentIndex = 0
            }
            return true
        }
        return false
    }

    // MARK: Playing collections (moved from LocalPlaylistStore/ServerPlaylistStore;
    // the stores keep the persistence halves: clearAndQueue and fillPlayQueue)

    @discardableResult
    func play(songIds: [String], serverId: Int, position: Int) -> Song? {
        guard store.clearAndQueue(songIds: songIds, serverId: serverId) else { return nil }
        return startQueuedCollection(position: position)
    }

    @discardableResult
    func play(songs: [Song], position: Int) -> Song? {
        guard store.clearAndQueue(songs: songs) else { return nil }
        return startQueuedCollection(position: position)
    }

    // TODO: Improve performance by preventing the need to convert to song objects
    @discardableResult
    func play(downloadedSongs: [DownloadedSong], position: Int) -> Song? {
        let songs = downloadedSongs.compactMap { store.song(downloadedSong: $0) }
        return play(songs: songs, position: position)
    }

    private func startQueuedCollection(position: Int) -> Song? {
        // Set player defaults
        queue.isShuffle = false

        // Sync the remote jukebox playlist before the skip that play sends
        activeMode.syncRemoteQueueIfNeeded()

        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)

        // Start the song
        return play(position: position)
    }

    @discardableResult
    func play(localPlaylistId: Int, position: Int, secondsOffset: Double = 0.0, byteOffset: Int = 0) -> Song? {
        // Turn off shuffle first so the playlist's songs fill the actual play queue
        // (currentPlaylistId would otherwise point at the shuffle queue)
        queue.isShuffle = false

        guard store.clearPlayQueue() else { return nil }
        guard store.fillPlayQueue(fromLocalPlaylistId: localPlaylistId, intoPlaylistId: queue.currentPlaylistId) else { return nil }

        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)

        // Offset-capability branch (not transport routing): the jukebox can't honor
        // byte/seconds offsets, so it syncs the remote playlist and skips instead
        if settings.isJukeboxEnabled {
            activeMode.syncRemoteQueueIfNeeded()
            return play(position: position)
        } else {
            // Start the song
            queue.currentIndex = position
            startSong(byteOffset: byteOffset, secondsOffset: secondsOffset)
            return queue.currentSong
        }
    }

    @discardableResult
    func play(bookmark: Bookmark) -> Song? {
        play(localPlaylistId: bookmark.localPlaylistId, position: bookmark.songIndex, secondsOffset: bookmark.offsetInSeconds, byteOffset: bookmark.offsetInBytes)
    }

    @discardableResult
    func playServerPlaylist(serverId: Int, serverPlaylistId: Int, position: Int) -> Song? {
        let songIds = store.songIds(serverId: serverId, serverPlaylistId: serverPlaylistId)
        return play(songIds: songIds, serverId: serverId, position: position)
    }

    // MARK: Queue-changed hooks (moved from AsyncSongsHelper, minus its notification posts)

    // Clears the live queue before a play-all/shuffle-all replaces it
    func prepareForPlayAll() {
        activeMode.prepareForPlayAll()
        queue.isShuffle = false
    }

    // The queue contents changed (songs appended/inserted): sync the remote playlist
    // in jukebox mode, or top up the stream queue locally
    func queueDidChange() {
        activeMode.queueDidChange()
    }

    // The queue was reordered or appended without wanting a stream-queue fill
    // (LocalPlaylist.queue/queueNext); jukebox mirrors it remotely, local no-ops
    func syncRemoteQueueIfNeeded() {
        activeMode.syncRemoteQueueIfNeeded()
    }
}

// The player's back-channel (Phase 8.5), attached weakly at the composition root.
// playerDidFinishSong and playerNeedsNextSongPrepared run SYNCHRONOUSLY on the
// player's stream GCD queue (gapless-critical — see PlayerDelegate.swift): they must
// not block, hop threads, or take new locks. The queue reads here are the same GRDB
// reads PlayQueue performed from that queue when the player held it directly.
extension PlaybackCoordinator: PlayerDelegate {
    var playerCurrentSong: Song? { queue.currentSong }
    var playerCurrentIndex: Int { queue.currentIndex }
    var playerNextSong: Song? { queue.nextSong }

    func playerDidFinishSong() {
        queue.incrementIndex()
    }

    func playerNeedsNextSongPrepared() {
        if let next = queue.nextSong {
            player.prepareNext(song: next)
        }
    }

    func playerRequestsStart(byteOffset: Int, secondsOffset: Double) {
        startSong(byteOffset: byteOffset, secondsOffset: secondsOffset)
    }

    func playerRequestsPlayCurrent() {
        playCurrent()
    }

    func playerRequestsPlayNext() {
        playNext()
    }

    func playerRequestsPlayPrev() {
        playPrevious()
    }
}
