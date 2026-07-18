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
    private let coordinator: PlaybackCoordinator

    private var hasSetup = false
    private var refreshTimer: Timer?

    // Stores references only; command registration and observers happen in setup()
    // so tests can construct freely without touching MPRemoteCommandCenter
    init(settings: SavedSettings, playQueue: PlayQueue, player: PlayerControlling, coordinator: PlaybackCoordinator) {
        self.settings = settings
        self.playQueue = playQueue
        self.player = player
        self.coordinator = coordinator
    }

    // MARK: Now playing info

    // Replaces PlayQueue.updateLockScreenInfo: writes the info dictionary and keeps a
    // 30 second timer running to keep the elapsed time in sync
    func refresh() {
        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.currentNowPlayingInfo()
            self.startRefreshTimer()
        }
    }

    // Internal, not private, for test access. This surface also drives CarPlay's
    // now playing screen, so the values must be precise — in particular the rate
    // must be 0 while paused or the system progress bars keep advancing
    func currentNowPlayingInfo() -> [String: Any] {
        var info = [String: Any]()

        if let song = playQueue.currentSong {
            info[MPMediaItemPropertyTitle] = song.title
            info[MPMediaItemPropertyAlbumTitle] = song.tagAlbumName
            info[MPMediaItemPropertyArtist] = song.tagArtistName
            info[MPMediaItemPropertyGenre] = song.genre
            if song.duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = song.duration
            }
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = playQueue.currentIndex
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = playQueue.count
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.progress
            info[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0

            if let coverArtId = song.coverArtId, settings.isLockScreenArtEnabled {
                if let image = AsyncCoverArtLoaderManager.shared.coverArtImage(serverId: song.serverId, coverArtId: coverArtId, isLarge: true) {
                    info[MPMediaItemPropertyArtwork] = Self.artwork(for: image)
                }
            }
        }

        return info
    }

    // Honors the consumer's requested size (the lock screen and CarPlay ask for
    // different sizes) instead of always returning the full stored bitmap. The
    // request handler can be called off-main; UIGraphicsImageRenderer is safe there.
    static func artwork(for image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: image.size) { size -> UIImage in
            // Never upscale; only render down when a smaller size is requested
            guard size.width < image.size.width || size.height < image.size.height else { return image }
            let fitScale = min(size.width / image.size.width, size.height / image.size.height)
            let fitSize = CGSize(width: image.size.width * fitScale, height: image.size.height * fitScale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3 // sharp on any display without shipping the full-size bitmap
            return UIGraphicsImageRenderer(size: fitSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: fitSize))
            }
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
        return coordinator.play() ? .success : .commandFailed
    }

    func handlePause() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        return coordinator.pause() ? .success : .commandFailed
    }

    func handleTogglePlayPause() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        return coordinator.togglePlayPause() ? .success : .commandFailed
    }

    func handleStop() -> MPRemoteCommandHandlerStatus {
        guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
        return coordinator.stop() ? .success : .commandFailed
    }

    func handleNextTrack() -> MPRemoteCommandHandlerStatus {
        guard playQueue.nextSong != nil else { return .noActionableNowPlayingItem }
        coordinator.playNext()
        return .success
    }

    func handlePreviousTrack() -> MPRemoteCommandHandlerStatus {
        guard playQueue.prevSong != nil else { return .noActionableNowPlayingItem }
        coordinator.playPrevious()
        return .success
    }

    func handleChangePlaybackPosition(seconds: Double) -> MPRemoteCommandHandlerStatus {
        if coordinator.seek(seconds: seconds) {
            return .success
        }
        // The local player only seeks while playing; report the queue state precisely
        return playQueue.currentSong != nil ? .commandFailed : .noActionableNowPlayingItem
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
                coordinator.shuffleToggle()
                return .success
            }
        } else if !playQueue.isShuffle {
            coordinator.shuffleToggle()
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
