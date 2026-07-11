//
//  PlaybackMode.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// The jukebox-vs-local strategy (Phase 8.8). Main-thread confined; owned and
// dispatched exclusively by PlaybackCoordinator — never registered in the container,
// never referenced by UI code. The active mode is computed from
// settings.isJukeboxEnabled so there is no duplicated mode state.
protocol PlaybackMode: AnyObject {
    var isPlaying: Bool { get }
    var canPlayVideos: Bool { get }

    // Mode switch side effects; both must be idempotent (they also run from the
    // coordinator's jukeboxEnabled/jukeboxDisabled observers for flips that
    // originate elsewhere, e.g. the jukebox disabling itself on an auth error)
    func activate()
    func deactivate()

    // Transport. The Bool is "did act" — NowPlayingService maps it to
    // MPRemoteCommandHandlerStatus.
    @discardableResult func play() -> Bool
    @discardableResult func pause() -> Bool
    @discardableResult func togglePlayPause() -> Bool
    @discardableResult func stop() -> Bool
    @discardableResult func seek(seconds: Double) -> Bool

    // Start playing the (non-video, or video-capable) song at a queue position
    func playSong(at position: Int, song: Song)

    // The queue contents changed: sync the remote playlist or top up the stream queue
    func queueDidChange()
    // The queue was reordered without new content (move, external queue writes):
    // jukebox mirrors the reorder remotely; local playback doesn't care
    func syncRemoteQueueIfNeeded()
    // The live queue is about to be replaced by a play-all/shuffle-all
    func prepareForPlayAll()
    // Shuffle was toggled; jukebox replaces the remote playlist and restarts
    func didToggleShuffle(currentIndex: Int)
}

final class LocalPlaybackMode: PlaybackMode {
    private let player: PlayerControlling
    private let streamManager: StreamManaging
    private let store: Store
    // The restart path ("play pressed while already playing") re-enters the
    // coordinator's debounced startSong; the coordinator owns this mode, so the
    // back-reference is unowned by construction
    private unowned let coordinator: PlaybackCoordinator

    init(player: PlayerControlling, streamManager: StreamManaging, store: Store, coordinator: PlaybackCoordinator) {
        self.player = player
        self.streamManager = streamManager
        self.store = store
        self.coordinator = coordinator
    }

    var isPlaying: Bool { player.isPlaying }
    var canPlayVideos: Bool { true }

    func activate() {
        // Nothing to do: local playback starts on the next transport command
    }

    func deactivate() {
        player.stop()
    }

    @discardableResult
    func play() -> Bool {
        if !player.isPlaying {
            player.playPause()
        } else {
            // Already playing: restart the current song from the top
            coordinator.startSong()
        }
        return true
    }

    @discardableResult
    func pause() -> Bool {
        guard player.isPlaying else { return false }
        player.pause()
        return true
    }

    @discardableResult
    func togglePlayPause() -> Bool {
        player.playPause()
        return true
    }

    @discardableResult
    func stop() -> Bool {
        guard player.isPlaying else { return false }
        player.stop()
        return true
    }

    @discardableResult
    func seek(seconds: Double) -> Bool {
        guard player.isPlaying else { return false }
        player.seekToPosition(seconds: seconds, fadeVolume: true)
        return true
    }

    func playSong(at position: Int, song: Song) {
        streamManager.removeAllStreams(except: song)
        if song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.playVideo, userInfo: ["song": song])
        } else {
            coordinator.startSong()
        }
    }

    func queueDidChange() {
        streamManager.fillStreamQueue(startDownload: player.isStarted)
    }

    func syncRemoteQueueIfNeeded() {
        // Local playback reads the queue live; nothing to sync
    }

    func prepareForPlayAll() {
        _ = store.clearPlayQueue()
    }

    func didToggleShuffle(currentIndex: Int) {
        // The coordinator already rebuilt the stream queue; nothing more to do
    }
}

final class JukeboxPlaybackMode: PlaybackMode {
    private let jukebox: Jukebox

    init(jukebox: Jukebox) {
        self.jukebox = jukebox
    }

    var isPlaying: Bool { jukebox.isPlaying }
    var canPlayVideos: Bool { false }

    func activate() {
        // Start polling the server's jukebox state
        jukebox.getInfo()
    }

    func deactivate() {
        // Stop the getInfo polling chain (the old code let it run forever)
        jukebox.cancelGetInfo()
    }

    @discardableResult
    func play() -> Bool {
        guard !jukebox.isPlaying else { return false }
        jukebox.play()
        return true
    }

    @discardableResult
    func pause() -> Bool {
        guard jukebox.isPlaying else { return false }
        jukebox.stop()
        return true
    }

    @discardableResult
    func togglePlayPause() -> Bool {
        if jukebox.isPlaying {
            jukebox.stop()
        } else {
            jukebox.play()
        }
        return true
    }

    @discardableResult
    func stop() -> Bool {
        guard jukebox.isPlaying else { return false }
        jukebox.stop()
        return true
    }

    @discardableResult
    func seek(seconds: Double) -> Bool {
        jukebox.seek(seconds: Int(seconds))
        return true
    }

    func playSong(at position: Int, song: Song) {
        jukebox.playSong(index: position)
    }

    func queueDidChange() {
        jukebox.replacePlaylistWithLocal()
    }

    func syncRemoteQueueIfNeeded() {
        jukebox.replacePlaylistWithLocal()
    }

    func prepareForPlayAll() {
        jukebox.clearPlaylist()
    }

    func didToggleShuffle(currentIndex: Int) {
        jukebox.replacePlaylistWithLocal()
        jukebox.playSong(index: currentIndex)
    }
}
