//
//  LockScreenAudioControls.swift
//  iSub
//
//  Created by Benjamin Baron on 11/15/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import MediaPlayer

@objc final class LockScreenAudioControls: NSObject {
    @objc static func setup() {
        
        // Enable lock screen controls
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        //
        // Enable commands and setup handlers
        //
        
        let remote = MPRemoteCommandCenter.shared()
        let settings = Settings.shared()
        let jukebox = Jukebox.shared()
        let audioEngine = AudioEngine.shared()
        let playQueue = PlayQueue.shared
        let music = Music.shared()
        
        // Play
        remote.playCommand.isEnabled = true
        remote.playCommand.addTarget { _ in
            guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
            if settings.isJukeboxEnabled {
                if !jukebox.isPlaying {
                    jukebox.play()
                    return .success
                }
            } else if let player = audioEngine.player, !player.isPlaying {
                player.playPause()
                return .success
            } else {
                music.startSong()
                return .success
            }
            return .commandFailed
        }
        
        // Pause
        remote.pauseCommand.isEnabled = true
        remote.pauseCommand.addTarget { _ in
            guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
            if settings.isJukeboxEnabled {
                if jukebox.isPlaying {
                    jukebox.stop()
                    return .success
                }
            } else if let player = audioEngine.player, player.isPlaying {
                player.pause()
                return .success
            }
            return .commandFailed
        }
        
        // Toggle play/pause
        remote.togglePlayPauseCommand.isEnabled = true
        remote.togglePlayPauseCommand.addTarget { _ in
            guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
            if settings.isJukeboxEnabled {
                if jukebox.isPlaying {
                    jukebox.stop()
                } else {
                    jukebox.play()
                }
                return .success
            } else if let player = audioEngine.player {
                player.playPause()
                return .success
            } else {
                music.startSong()
                return .success
            }
        }
        
        // Stop
        remote.stopCommand.isEnabled = true
        remote.stopCommand.addTarget { _ in
            guard playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
            if settings.isJukeboxEnabled {
                if jukebox.isPlaying {
                    jukebox.stop()
                    return .success
                }
            } else if let player = audioEngine.player, player.isPlaying {
                player.stop()
                return .success
            }
            return .commandFailed
        }
        
        // Next Track
        remote.nextTrackCommand.isEnabled = true
        remote.nextTrackCommand.addTarget { _ in
            guard playQueue.nextSong != nil else { return .noActionableNowPlayingItem }
            music.nextSong()
            return .commandFailed
        }
        
        // Previous Track
        remote.previousTrackCommand.isEnabled = true
        remote.previousTrackCommand.addTarget { _ in
            guard playQueue.prevSong != nil else { return .noActionableNowPlayingItem }
            music.prevSong()
            return .commandFailed
        }
        
        // Repeat Mode
        remote.changeRepeatModeCommand.isEnabled = true
        remote.changeRepeatModeCommand.addTarget { event in
            guard let repeatEvent = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            
            switch repeatEvent.repeatType {
            case .off: playQueue.repeatMode = .none
            case .one: playQueue.repeatMode = .one
            case .all: playQueue.repeatMode = .all
            default: return .commandFailed
            }
            return .success
        }
        let currentRepeatType: MPRepeatType
        switch playQueue.repeatMode {
        case .one: currentRepeatType = .one
        case .all: currentRepeatType = .all
        default: currentRepeatType = .off
        }
        remote.changeRepeatModeCommand.currentRepeatType = currentRepeatType
        
        
        // Shuffle Mode
        remote.changeShuffleModeCommand.isEnabled = true
        remote.changeShuffleModeCommand.addTarget { event in
            guard let shuffleEvent = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            if shuffleEvent.shuffleType == .off {
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
        remote.changeShuffleModeCommand.currentShuffleType = playQueue.isShuffle ? .items : .off
        
        // Seeking
        remote.changePlaybackPositionCommand.isEnabled = true
        remote.changePlaybackPositionCommand.addTarget { event in
            guard settings.isJukeboxEnabled || playQueue.currentSong != nil else { return .noActionableNowPlayingItem }
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            if let player = audioEngine.player, player.isPlaying {
                player.seekToPosition(inSeconds: positionEvent.positionTime, fadeVolume: true)
                return .success
            }
            return .commandFailed
        }
    }
}
