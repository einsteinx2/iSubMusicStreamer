//
//  ScrobbleService.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Pure scrobble threshold logic, extracted from the old Social singleton so it can
// be tested without a player or timers.
enum ScrobbleRules {
    // Submit "now playing" after this many seconds of playback
    static let nowPlayingDelay = 10.0

    // Scrobble in 30 seconds, or the settings percentage of the song duration when
    // the duration is known
    static func scrobbleDelay(duration: Int, scrobblePercent: Float) -> Double {
        if duration > 0 {
            return Double(scrobblePercent) * Double(duration)
        }
        return 30.0
    }
}

// Replaces the Social singleton (Phase 8.2). The old design ran the threshold checks
// inside BassPlayer's output render callback on every audio buffer; this service is
// driven entirely off the audio path instead: playback lifecycle notifications reset
// the per-song state and a 5 second main-thread timer polls the player for progress.
// Threshold detection can therefore fire up to 5 seconds late, never early — safe
// for scrobbling semantics.
final class ScrobbleService {
    private let settings: SavedSettings
    private let session: ServerSession
    private let player: PlayerControlling
    // Seam for tests; the default performs the real scrobble network call
    private let submit: (Song, _ isSubmission: Bool) -> Void

    private var timer: Timer?
    private var hasSubmittedNowPlaying = false
    private var hasScrobbled = false
    private var lastSongId: String?

    init(settings: SavedSettings, session: ServerSession, player: PlayerControlling,
         submit: ((Song, _ isSubmission: Bool) -> Void)? = nil) {
        self.settings = settings
        self.session = session
        self.player = player
        self.submit = submit ?? { song, isSubmission in
            Task {
                do {
                    try await AsyncScrobbleLoader(song: song, isSubmission: isSubmission).load()
                    DDLogInfo("[ScrobbleService] Scrobble successfully completed for song \(song.title)")
                } catch {
                    DDLogError("[ScrobbleService] Scrobble failed for song \(song.title), error: \(error)")
                }
            }
        }

        // All of these are posted on the main thread. The old playerClearSocial()
        // call sites (cleanup, startSong, songEnded) post bassFreed,
        // songPlaybackStarted, and songPlaybackEnded respectively on the same paths,
        // so resetting on these notifications preserves the per-song flag lifecycle.
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackStarted), name: Notifications.songPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackPaused), name: Notifications.songPlaybackPaused)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackStopped), name: Notifications.songPlaybackEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackStopped), name: Notifications.bassFreed)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        timer?.invalidate()
    }

    @objc private func playbackStarted() {
        resetFlags()
        startTimer()
    }

    @objc private func playbackPaused() {
        // Flags survive a pause, matching the old behavior (the render callback
        // simply stopped running); only the polling stops
        stopTimer()
    }

    @objc private func playbackStopped() {
        resetFlags()
        stopTimer()
    }

    private func resetFlags() {
        hasSubmittedNowPlaying = false
        hasScrobbled = false
        lastSongId = nil
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.tick()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Internal for tests; the timer target. In jukebox mode currentStream is nil so
    // the tick is a harmless no-op, matching the old render-callback-only driver.
    func tick() {
        handle(song: player.currentStream?.song, progress: player.progress)
    }

    // Internal for tests. Mirrors the old Social.playerHandleSocial exactly: the
    // flags flip on threshold crossing regardless of the submission gates, and the
    // gates only suppress the network call.
    func handle(song: Song?, progress: Double) {
        // Belt-and-braces: if the song changed without a lifecycle notification,
        // start the per-song state over
        if song?.id != lastSongId {
            hasSubmittedNowPlaying = false
            hasScrobbled = false
            lastSongId = song?.id
        }

        if !hasSubmittedNowPlaying && progress >= ScrobbleRules.nowPlayingDelay {
            hasSubmittedNowPlaying = true
            // Now-playing submission is gated only on offline mode, matching the old
            // Social.scrobbleSongAsPlaying
            if !session.isOfflineMode, let song {
                submit(song, false)
            }
        }

        if !hasScrobbled && progress >= ScrobbleRules.scrobbleDelay(duration: song?.duration ?? 0, scrobblePercent: settings.scrobblePercent) {
            hasScrobbled = true
            if settings.isScrobbleEnabled && !session.isOfflineMode, let song {
                submit(song, true)
            }
        }
    }
}
