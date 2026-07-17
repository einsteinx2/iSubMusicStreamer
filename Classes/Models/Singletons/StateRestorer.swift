//
//  StateRestorer.swift
//  iSub
//
//  Created by Ben Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Persists playback state (play queue indices, player offsets, recover flags) on a
// 3.3 second timer and restores it at launch. Extracted from SavedSettings; all
// dependencies point forward (settings/player/playQueue/defaults) and nothing
// depends on this class, so it is constructed with plain constructor injection.
//
// TODO: Refactor all this state saving stuff to use Codable etc
final class StateRestorer {
    private let settings: SavedSettings
    private let player: PlayerControlling
    private let playQueue: PlayQueue

    // The same UserDefaults store backing SavedSettings' @UserDefault wrappers,
    // resolved at access time so the test sandbox swap affects existing instances
    private var defaults: UserDefaults { SavedSettings.defaults }

    init(settings: SavedSettings, player: PlayerControlling, playQueue: PlayQueue) {
        self.settings = settings
        self.player = player
        self.playQueue = playQueue
    }

    private struct State {
        var isPlaying: Bool = false
        var isShuffle: Bool = false
        var normalPlaylistIndex: Int = 0
        var shufflePlaylistIndex: Int = 0
        var repeatMode: RepeatMode = .none
        var kiloBitrate: Int = 0
        var byteOffset: Int = 0
        var secondsOffset: Double = 0
        var isRecover: Bool = false
        var recoverSetting: Int = 0
        var currentServer: Server?
    }

    private var state = State()

    // Must run in didFinishLaunching BEFORE SceneDelegate calls streamManager.setup()
    // and playQueue.resumeSong(): loadState() writes the play queue indices and player
    // offsets that the resume path reads
    func setup() {
        // Load saved state first
        loadState()

        // Start the timer
        Timer.scheduledTimer(withTimeInterval: 3.3, repeats: true) { _ in
            self.saveState()
        }
    }

    func loadState() {
        state.isPlaying = settings.isJukeboxEnabled ? false : defaults.bool(forKey: .isPlaying)

        state.isShuffle = defaults.bool(forKey: .isShuffle)
        playQueue.isShuffle = state.isShuffle

        state.normalPlaylistIndex = defaults.integer(forKey: .normalPlaylistIndex)
        playQueue.normalIndex = state.normalPlaylistIndex;

        state.shufflePlaylistIndex = defaults.integer(forKey: .shufflePlaylistIndex)
        playQueue.shuffleIndex = state.shufflePlaylistIndex

        state.repeatMode = RepeatMode(rawValue: defaults.integer(forKey: .repeatMode)) ?? .none
        playQueue.repeatMode = state.repeatMode;

        state.kiloBitrate = defaults.integer(forKey: .kiloBitrate)
        state.byteOffset = settings.byteOffset
        state.secondsOffset = settings.seekTime
        state.isRecover = settings.isRecover
        state.recoverSetting = settings.recoverSetting

        player.startByteOffset = state.byteOffset
        player.startSecondsOffset = state.secondsOffset
    }

    // Reads the live playback state for a context snapshot. When the player has no
    // active stream its progress/currentByteOffset read 0 (see BassPlayer.progress),
    // so fall back to the primed start offsets — otherwise switching away from a
    // context that was restored but never played would zero its saved seek position.
    func captureSnapshot() -> PlayQueueStateSnapshot {
        PlayQueueStateSnapshot(
            isShuffle: playQueue.isShuffle,
            repeatMode: playQueue.repeatMode,
            normalIndex: playQueue.normalIndex,
            shuffleIndex: playQueue.shuffleIndex,
            seekTime: player.isStarted ? player.progress : player.startSecondsOffset,
            byteOffset: player.isStarted ? player.currentByteOffset : player.startByteOffset,
            kiloBitrate: player.isStarted && player.kiloBitrate >= 0 ? player.kiloBitrate : state.kiloBitrate)
    }

    // Paused restore for a context switch: mirrors loadState()'s no-recover shape —
    // queue fields, primed player offsets, and the live defaults with isPlaying and
    // recover off — and refreshes the internal diff cache so the next save tick
    // doesn't rewrite stale values over what was just applied.
    func apply(snapshot: PlayQueueStateSnapshot) {
        playQueue.isShuffle = snapshot.isShuffle
        playQueue.repeatMode = snapshot.repeatMode
        playQueue.normalIndex = snapshot.normalIndex
        playQueue.shuffleIndex = snapshot.shuffleIndex

        player.startByteOffset = snapshot.byteOffset
        player.startSecondsOffset = snapshot.seekTime

        state.isPlaying = false
        state.isShuffle = snapshot.isShuffle
        state.normalPlaylistIndex = snapshot.normalIndex
        state.shufflePlaylistIndex = snapshot.shuffleIndex
        state.repeatMode = snapshot.repeatMode
        state.kiloBitrate = snapshot.kiloBitrate
        state.byteOffset = snapshot.byteOffset
        state.secondsOffset = snapshot.seekTime
        state.isRecover = false

        defaults.set(false, forKey: .isPlaying)
        defaults.set(snapshot.isShuffle, forKey: .isShuffle)
        defaults.set(snapshot.normalIndex, forKey: .normalPlaylistIndex)
        defaults.set(snapshot.shuffleIndex, forKey: .shufflePlaylistIndex)
        defaults.set(snapshot.repeatMode.rawValue, forKey: .repeatMode)
        defaults.set(snapshot.kiloBitrate, forKey: .kiloBitrate)
        defaults.set(snapshot.seekTime, forKey: .seekTime)
        defaults.set(snapshot.byteOffset, forKey: .byteOffset)
        defaults.set(false, forKey: .recover)
        defaults.synchronize()
    }

    func saveState() {
        var isDefaultsDirty = false

        if player.isPlaying != state.isPlaying {
            if settings.isJukeboxEnabled {
                state.isPlaying = false
            } else {
                state.isPlaying = player.isPlaying
            }

            defaults.set(state.isPlaying, forKey: .isPlaying)
            isDefaultsDirty = true
        }

        if playQueue.isShuffle != state.isShuffle {
            state.isShuffle = playQueue.isShuffle
            defaults.set(state.isShuffle, forKey: .isShuffle)
            isDefaultsDirty = true
        }

        if playQueue.normalIndex != state.normalPlaylistIndex {
            state.normalPlaylistIndex = playQueue.normalIndex
            defaults.set(state.normalPlaylistIndex, forKey: .normalPlaylistIndex)
            isDefaultsDirty = true
        }

        if playQueue.shuffleIndex != state.shufflePlaylistIndex {
            state.shufflePlaylistIndex = playQueue.shuffleIndex
            defaults.set(state.shufflePlaylistIndex, forKey: .shufflePlaylistIndex)
            isDefaultsDirty = true
        }

        if playQueue.repeatMode != state.repeatMode {
            state.repeatMode = playQueue.repeatMode
            defaults.set(state.repeatMode.rawValue, forKey: .repeatMode)
            isDefaultsDirty = true
        }

        if player.kiloBitrate != state.kiloBitrate && player.kiloBitrate >= 0 {
            state.kiloBitrate = player.kiloBitrate;
            defaults.set(state.kiloBitrate, forKey: .kiloBitrate)
            isDefaultsDirty = true
        }

        // A stopped player reports progress/currentByteOffset of 0, so fall back to
        // the primed start offsets — otherwise the first tick after a paused launch or
        // a context switch clobbers the saved position with zero
        let liveSecondsOffset = player.isStarted ? player.progress : player.startSecondsOffset
        if state.secondsOffset != liveSecondsOffset {
            state.secondsOffset = liveSecondsOffset
            defaults.set(state.secondsOffset, forKey: .seekTime)
            isDefaultsDirty = true
        }

        let liveByteOffset = player.isStarted ? player.currentByteOffset : player.startByteOffset
        if state.byteOffset != liveByteOffset {
            state.byteOffset = liveByteOffset
            defaults.set(state.byteOffset, forKey: .byteOffset)
            isDefaultsDirty = true
        }

        var newIsRecover = false
        if state.isPlaying {
            newIsRecover = (state.recoverSetting == 0)
        } else {
            newIsRecover = false
        }

        if state.isRecover != newIsRecover {
            state.isRecover = newIsRecover
            defaults.set(state.isRecover, forKey: .recover)
            isDefaultsDirty = true
        }

        // Only synchronize to disk if necessary
        if isDefaultsDirty {
            defaults.synchronize()
        }
    }
}
