//
//  Social.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

final class Social {
    @LazyInjected private var player: BassGaplessPlayer
    @LazyInjected private var settings: Settings
    @LazyInjected private var playQueue: PlayQueue
    
    private let nowPlayingDelay = 10.0
    private var scrobbleDelay: Double {
        // Scrobble in 30 seconds (or settings amount) if not canceled
        var scrobbleDelay = 30.0
        if let currentSong = player.currentStream?.song, currentSong.duration > 0 {
            scrobbleDelay = Double(settings.scrobblePercent) * Double(currentSong.duration)
        }
        return scrobbleDelay
    }
    
    // MARK: Player
    
    private var playerHasScrobbled = false
    private var playerHasSubmittedNowPlaying = false
    
    func playerClearSocial() {
        playerHasSubmittedNowPlaying = false
        playerHasScrobbled = false
    }
    
    func playerHandleSocial() {
        if !playerHasSubmittedNowPlaying && player.progress >= nowPlayingDelay {
            playerHasSubmittedNowPlaying = true
            scrobbleSongAsPlaying()
        }
        
        if !playerHasScrobbled && player.progress >= scrobbleDelay {
            playerHasScrobbled = true
            scrobbleSongAsSubmission()
        }
    }
    
    // MARK: Scrobbling
    
    private func scrobbleSongAsSubmission() {
        if settings.isScrobbleEnabled && !settings.isOfflineMode, let currentSong = playQueue.currentSong {
            scrobble(song: currentSong, isSubmission: true)
        }
    }
    
    private func scrobbleSongAsPlaying() {
        if !settings.isOfflineMode, let currentSong = playQueue.currentSong {
            scrobble(song: currentSong, isSubmission: false)
        }
    }
    
    private func scrobble(song: Song, isSubmission: Bool) {
        let loader = ScrobbleLoader(song: song, isSubmission: isSubmission) { _, success, error in
            if success {
                DDLogInfo("[Social] Scrobble successfully completed for song \(song.title)")
            } else {
                DDLogError("[Social] Scrobble failed for song \(song.title), error: \(error?.localizedDescription ?? "Unknown")")
            }
        }
        loader.startLoad()
    }
}
