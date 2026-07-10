//
//  Social.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Abstraction over play-time scrobbling so the player can be unit tested without
// spawning background scrobble network tasks (registered in DependencyInjection.swift)
protocol SocialScrobbling: AnyObject {
    func playerClearSocial()
    func playerHandleSocial(currentSong: Song?, progress: Double)
}

extension Social: SocialScrobbling {}

final class Social {
    private let settings: SavedSettings

    init(settings: SavedSettings) {
        self.settings = settings
    }

    private let nowPlayingDelay = 10.0

    // Scrobble in 30 seconds (or settings amount) if not canceled
    private func scrobbleDelay(currentSong: Song?) -> Double {
        var scrobbleDelay = 30.0
        if let currentSong, currentSong.duration > 0 {
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

    // The caller (BassPlayer's output callback) passes the playing stream's song and
    // progress so no database query ever runs on the audio render thread
    func playerHandleSocial(currentSong: Song?, progress: Double) {
        if !playerHasSubmittedNowPlaying && progress >= nowPlayingDelay {
            playerHasSubmittedNowPlaying = true
            scrobbleSongAsPlaying(currentSong: currentSong)
        }

        if !playerHasScrobbled && progress >= scrobbleDelay(currentSong: currentSong) {
            playerHasScrobbled = true
            scrobbleSongAsSubmission(currentSong: currentSong)
        }
    }

    // MARK: Scrobbling

    private func scrobbleSongAsSubmission(currentSong: Song?) {
        if settings.isScrobbleEnabled && !settings.isOfflineMode, let currentSong {
            scrobble(song: currentSong, isSubmission: true)
        }
    }

    private func scrobbleSongAsPlaying(currentSong: Song?) {
        if !settings.isOfflineMode, let currentSong {
            scrobble(song: currentSong, isSubmission: false)
        }
    }
    
    private func scrobble(song: Song, isSubmission: Bool) {
        Task {
            do {
                try await AsyncScrobbleLoader(song: song, isSubmission: isSubmission).load()
                DDLogInfo("[Social] Scrobble successfully completed for song \(song.title)")
            } catch {
                DDLogError("[Social] Scrobble failed for song \(song.title), error: \(error)")
            }
        }
    }
}
