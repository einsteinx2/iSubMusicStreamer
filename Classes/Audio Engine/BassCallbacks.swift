//
//  BassCallbacks.swift
//  LocalMusicPlayer
//
//  Created by Benjamin Baron on 10/20/20.
//

import Foundation
import CocoaLumberjackSwift

// TODO: Test if autoreleasepool is actual necessary like it is in Obj-C

// MARK: Main Output Callback

func bassStreamProc(handle: HSYNC, buffer: UnsafeMutableRawPointer?, length: DWORD, userInfo: UnsafeMutableRawPointer?) -> DWORD {
    autoreleasepool {
        guard let userInfo = userInfo, let buffer = buffer else { return 0 }
        let player: BassPlayer = Bridging.bridge(ptr: userInfo)
        
        return player.bassGetOutputData(buffer: buffer, length: length)
    }
}

// MARK: Individual Song Decode Stream Callbacks

var bassFileProcs = BASS_FILEPROCS(close: bassFileCloseProc, length: bassLengthProc, read: bassReadProc, seek: bassSeekProc)

func bassLengthProc(userInfo: UnsafeMutableRawPointer?) -> QWORD {
    autoreleasepool {
        guard let userInfo = userInfo else { return 0 }
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        
        let length = bassStream.fileSize
        DDLogInfo("[bassLengthProc] checking length: \(length) for song: \(bassStream.song)")
        return length
    }
}

func bassReadProc(buffer: UnsafeMutableRawPointer?, length: DWORD, userInfo: UnsafeMutableRawPointer?) -> DWORD {
    autoreleasepool {
        guard let userInfo = userInfo, let buffer = buffer else { return 0 }
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        
        return bassStream.readBytes(buffer: buffer, length: length)
    }
}

func bassSeekProc(offset: QWORD, userInfo: UnsafeMutableRawPointer?) -> ObjCBool {
    autoreleasepool {
        guard let userInfo = userInfo else { return false }
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        
        let success = bassStream.seek(to: offset)
        DDLogInfo("[bassSeekProc] seeking to \(offset) success: \(success)")
        return ObjCBool(success)
    }
}

func bassFileCloseProc(userInfo: UnsafeMutableRawPointer?) {
    autoreleasepool {
        guard let userInfo = userInfo else { return }
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        
        bassStream.shouldWaitForData = false
    }
}

// MARK: Seek Fade Callback

func bassSlideSyncProc(handle: HSYNC, channel: DWORD, data: DWORD, userInfo: UnsafeMutableRawPointer?) {
    autoreleasepool {
        guard let userInfo = userInfo else { return }
        let player: BassPlayer = Bridging.bridge(ptr: userInfo)
        
        BASS_SetDevice(Bass.outputDeviceNumber)
        var volumeLevel: Float = 0.0
        let success = BASS_ChannelGetAttribute(player.outStream, UInt32(BASS_ATTRIB_VOL), &volumeLevel)
        if success && volumeLevel == 0 {
            BASS_ChannelSlideAttribute(player.outStream, UInt32(BASS_ATTRIB_VOL), 1, 200)
        }
    }
}

// MARK: Song End Callback

func bassEndSyncProc(handle: HSYNC, channel: DWORD, data: DWORD, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else { return }
    
    // Make sure we're using the right device
    BASS_SetDevice(Bass.outputDeviceNumber)
    
    autoreleasepool {
        DDLogInfo("[bassEndSyncProc] Stream End Callback called")
        
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        guard let player = bassStream.player else { return }
        
        // This must be done in the stream GCD queue because if we do it in this thread
        // it will pause the audio output momentarily while it's loading the stream
        player.streamGcdQueue.async {
            // Prepare the next song in the queue
            guard let nextSong = PlayQueue.shared.nextSong else { return }
            DDLogInfo("[bassEndSyncProc]  Preparing stream for: \(nextSong)")
            if let nextStream = Bass.prepareStream(song: nextSong, player: player) {
                DDLogInfo("[bassEndSyncProc] Stream prepared successfully for: \(nextSong)")
                synchronized(player.streamQueueSync) {
                    player.streamQueue.append(nextStream)
                }
                BASS_Mixer_StreamAddChannel(player.mixerStream, nextStream.hstream, DWORD(BASS_MIXER_NORAMPIN))
            } else {
                DDLogInfo("[bassEndSyncProc] Could NOT create stream for: \(nextSong)")
                bassStream.isNextSongStreamFailed = true
            }
            
            // Mark as ended and set the buffer space til end for the UI
//            bassStream.bufferSpaceTilSongEnd = player.ringBuffer.filledSpaceLength
//            bassStream.isEnded = true
        }
    }
}

// MARK: BPM Callback

//func bassBPMProc(handle: HSTREAM, bpm: Float, userInfo: UnsafeMutableRawPointer?) {
//    guard let userInfo = userInfo else { return }
//
//    autoreleasepool {
//        let player: BassPlayer = Bridging.bridge(ptr: userInfo)
//        player.currentSongBPM = bpm
//    }
//}
