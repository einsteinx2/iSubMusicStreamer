//
//  PlayerDelegate.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// The player's one seam back to the play queue (Phase 8.5), implemented by
// PlaybackCoordinator and attached weakly at the composition root. Replaces
// BassPlayer's direct weak PlayQueue reference.
protocol PlayerDelegate: AnyObject {
    // Queue queries. Callable from any thread; implementations perform the same
    // GRDB reads PlayQueue did when the player held it directly.
    var playerCurrentSong: Song? { get }
    var playerCurrentIndex: Int { get }
    var playerNextSong: Song? { get }

    // GAPLESS-CRITICAL: both are called SYNCHRONOUSLY on the player's stream GCD
    // queue during the song-end sequence. Implementations must not block, hop
    // threads, or take new locks. playerDidFinishSong advances the queue index
    // before the playback notifications post; playerNeedsNextSongPrepared is called
    // after the ended stream is freed (so prepareNext's streamQueue.count == 1 guard
    // passes) and should push player.prepareNext(song:) with the next queue song.
    func playerDidFinishSong()
    func playerNeedsNextSongPrepared()

    // Control-flow requests, replacing the player's direct playQueue.play* calls
    func playerRequestsStart(byteOffset: Int, secondsOffset: Double)
    func playerRequestsPlayCurrent()
    func playerRequestsPlayNext()
    func playerRequestsPlayPrev()
}
