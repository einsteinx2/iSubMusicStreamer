//
//  NowPlayingService.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import MediaPlayer

// Owns the system now-playing surface (Phase 8.3): the MPRemoteCommandCenter
// handlers that used to live in the static LockScreenAudioControls struct, and the
// MPNowPlayingInfoCenter updates that used to live in PlayQueue.updateLockScreenInfo.
// Driven by playback notifications and a 30 second progress timer instead of direct
// calls from the player.
final class NowPlayingService {
    private var remote: MPRemoteCommandCenter { MPRemoteCommandCenter.shared() }
    private let settings: SavedSettings
    private let playQueue: PlayQueue
    private let player: PlayerControlling
    private let jukebox: Jukebox

    private var hasSetup = false
    private var refreshTimer: Timer?

    // Stores references only; command registration and observers happen in setup()
    // so tests can construct freely without touching MPRemoteCommandCenter
    init(settings: SavedSettings, playQueue: PlayQueue, player: PlayerControlling, jukebox: Jukebox) {
        self.settings = settings
        self.playQueue = playQueue
        self.player = player
        self.jukebox = jukebox
    }

    // MARK: Now playing info

    // Replaces PlayQueue.updateLockScreenInfo: writes the info dictionary and keeps a
    // 30 second timer running to keep the elapsed time in sync
    func refresh() {
        DispatchQueue.main.async {
            var info = [String: Any]()

            if let song = self.playQueue.currentSong {
                info[MPMediaItemPropertyTitle] = song.title
                info[MPMediaItemPropertyAlbumTitle] = song.tagAlbumName
                info[MPMediaItemPropertyArtist] = song.tagArtistName
                info[MPMediaItemPropertyGenre] = song.genre
                if song.duration > 0 {
                    info[MPMediaItemPropertyPlaybackDuration] = song.duration
                }
                info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = self.playQueue.currentIndex
                info[MPNowPlayingInfoPropertyPlaybackQueueCount] = self.playQueue.count
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.player.progress
                info[MPNowPlayingInfoPropertyPlaybackRate] = 1

                if let coverArtId = song.coverArtId, self.settings.isLockScreenArtEnabled {
                    if let image = AsyncCoverArtLoaderManager.shared.coverArtImage(serverId: song.serverId, coverArtId: coverArtId, isLarge: true) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { size -> UIImage in
                            return image
                        }
                        info[MPMediaItemPropertyArtwork] = artwork
                    }
                }
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = info

            self.startRefreshTimer()
        }
    }

    // The old code re-performed updateLockScreenInfo every 30 seconds after the
    // first call, forever; a repeating timer is the same behavior
    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.refresh()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: Remote command handlers (internal, not private, for test access)

    func handlePlay() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        if settings.isJukeboxEnabled {
            if !jukebox.isPlaying {
                jukebox.play()
                return .success
            }
        } else if !player.isPlaying {
            player.playPause()
            return .success
        } else {
            playQueue.startSong()
            return .success
        }
        return .commandFailed
    }

    func handlePause() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        if settings.isJukeboxEnabled {
            if jukebox.isPlaying {
                jukebox.stop()
                return .success
            }
        } else if player.isPlaying {
            player.pause()
            return .success
        }
        return .commandFailed
    }

    func handleTogglePlayPause() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        if settings.isJukeboxEnabled {
            if jukebox.isPlaying {
                jukebox.stop()
            } else {
                jukebox.play()
            }
            return .success
        } else {
            player.playPause()
            return .success
        }
    }

    func handleStop() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        if settings.isJukeboxEnabled {
            if jukebox.isPlaying {
                jukebox.stop()
                return .success
            }
        } else if player.isPlaying {
            player.stop()
            return .success
        }
        return .commandFailed
    }

    func handleNextTrack() -> MPRemoteCommandHandlerStatus {
        guard playQueue.nextSong != nil else { return .noActionableNowPlayingItem }
        playQueue.playNextSong()
        return .success
    }

    func handlePreviousTrack() -> MPRemoteCommandHandlerStatus {
        guard playQueue.prevSong != nil else { return .noActionableNowPlayingItem }
        playQueue.playPrevSong()
        return .success
    }

    func handleChangePlaybackPosition(seconds: Double) -> MPRemoteCommandHandlerStatus {
        guard settings.isJukeboxEnabled || playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        if settings.isJukeboxEnabled {
            jukebox.seek(seconds: Int(seconds))
            return .success
        } else if player.isPlaying {
            player.seekToPosition(seconds: seconds, fadeVolume: true)
            return .success
        }
        return .commandFailed
    }

    func handleChangeRepeatMode(_ repeatType: MPRepeatType) -> MPRemoteCommandHandlerStatus {
        switch repeatType {
        case .off: playQueue.repeatMode = .none
        case .one: playQueue.repeatMode = .one
        case .all: playQueue.repeatMode = .all
        default: return .commandFailed
        }
        return .success
    }

    func handleChangeShuffleMode(_ shuffleType: MPShuffleType) -> MPRemoteCommandHandlerStatus {
        if shuffleType == .off {
            if playQueue.isShuffle {
                playQueue.shuffleToggle()
                return .success
            }
        } else if !playQueue.isShuffle {
            playQueue.shuffleToggle()
            return .success
        }
        return .commandFailed
    }

    // MARK: OS state sync

    @objc private func syncRepeatType() {
        let repeatType: MPRepeatType
        switch playQueue.repeatMode {
        case .none: repeatType = .off
        case .one: repeatType = .one
        case .all: repeatType = .all
        }
        remote.changeRepeatModeCommand.currentRepeatType = repeatType
    }

    @objc private func syncShuffleType() {
        remote.changeShuffleModeCommand.currentShuffleType = playQueue.isShuffle ? .items : .off
    }

    @objc private func refreshFromNotification() {
        refresh()
    }

    // MARK: Setup

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true

        // Enable lock screen controls
        UIApplication.shared.beginReceivingRemoteControlEvents()

        // The player posts these on every playback transition; they replace the
        // direct updateLockScreenInfo calls that used to live in BassPlayer
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshFromNotification), name: Notifications.songPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshFromNotification), name: Notifications.songPlaybackPaused)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshFromNotification), name: Notifications.songPlaybackEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshFromNotification), name: Notifications.currentPlaylistIndexChanged)
        // These replace the MPRemoteCommandCenter writes that used to live in
        // PlayQueue's repeatMode didSet and didToggleShuffle
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(syncRepeatType), name: Notifications.repeatModeChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(syncShuffleType), name: Notifications.currentPlaylistShuffleToggled)

        //
        // Enable commands and setup handlers
        //

        remote.playCommand.isEnabled = true
        remote.playCommand.addTarget { [unowned self] _ in handlePlay() }

        remote.pauseCommand.isEnabled = true
        remote.pauseCommand.addTarget { [unowned self] _ in handlePause() }

        remote.togglePlayPauseCommand.isEnabled = true
        remote.togglePlayPauseCommand.addTarget { [unowned self] _ in handleTogglePlayPause() }

        remote.stopCommand.isEnabled = true
        remote.stopCommand.addTarget { [unowned self] _ in handleStop() }

        remote.nextTrackCommand.isEnabled = true
        remote.nextTrackCommand.addTarget { [unowned self] _ in handleNextTrack() }

        remote.previousTrackCommand.isEnabled = true
        remote.previousTrackCommand.addTarget { [unowned self] _ in handlePreviousTrack() }

        remote.changeRepeatModeCommand.isEnabled = true
        remote.changeRepeatModeCommand.addTarget { [unowned self] event in
            guard let repeatEvent = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            return handleChangeRepeatMode(repeatEvent.repeatType)
        }
        syncRepeatType()

        remote.changeShuffleModeCommand.isEnabled = true
        remote.changeShuffleModeCommand.addTarget { [unowned self] event in
            guard let shuffleEvent = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            return handleChangeShuffleMode(shuffleEvent.shuffleType)
        }
        syncShuffleType()

        remote.changePlaybackPositionCommand.isEnabled = true
        remote.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return handleChangePlaybackPosition(seconds: positionEvent.positionTime)
        }
    }
}
