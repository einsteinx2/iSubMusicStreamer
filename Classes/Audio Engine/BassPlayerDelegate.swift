//
//  BassPlayerDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 1/28/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class BassPlayerDelegate: NSObject, BassGaplessPlayerDelegate {
    @LazyInjected private var social: Social
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var streamManager: StreamManager
    
    func bassFirstStreamStarted(_ player: BassGaplessPlayer) {
        social.playerClearSocial()
    }
    
    func bassSongEndedCalled(_ player: BassGaplessPlayer) {
        // Increment current playlist index
        playQueue.incrementIndex()
        
        // Clear the social post status
        social.playerClearSocial()
    }
    
    func bassFreed(_ player: BassGaplessPlayer) {
        social.playerClearSocial()
    }
    
    func bassIndex(atOffset offset: Int, from index: Int, player: BassGaplessPlayer) -> Int {
        return playQueue.index(offset: offset, fromIndex: index)
    }
    
    func bassSong(for index: Int, player: BassGaplessPlayer) -> Song? {
        return playQueue.song(index: index)
    }
    
    func bassCurrentPlaylistIndex(_ player: BassGaplessPlayer) -> Int {
        return playQueue.currentIndex
    }
    
    func bassRetrySong(at index: Int, player: BassGaplessPlayer) {
        playQueue.playSong(position: index)
    }
    
    func bassUpdateLockScreenInfo(_ player: BassGaplessPlayer) {
        playQueue.updateLockScreenInfo()
    }
    
    func bassRetrySongAtOffset(inBytes bytes: Int, andSeconds seconds: Int, player: BassGaplessPlayer) {
        playQueue.startSong(offsetInBytes: bytes, offsetInSeconds: Double(seconds))
    }
    
    func bassFailedToCreateNextStream(for index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        if let song = playQueue.song(index: index), let handler = streamManager.handler(song: song) {
            if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
                // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                playQueue.playSong(position: index)
            }
        }
    }
    
    func bassRetrievingOutputData(_ player: BassGaplessPlayer) {
        social.playerHandleSocial()
    }
}
