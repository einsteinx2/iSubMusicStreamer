//
//  BassCallbacks.swift
//  LocalMusicPlayer
//
//  Created by Benjamin Baron on 10/20/20.
//

import Foundation
import CocoaLumberjackSwift

// MARK: Main Output Callback

func bassStreamProc(handle: HSYNC, buffer: UnsafeMutableRawPointer?, length: DWORD, userInfo: UnsafeMutableRawPointer?) -> DWORD {
    guard let userInfo = userInfo, let buffer = buffer else { return 0 }
    
    return autoreleasepool {
        let player: BassGaplessPlayer = Bridging.bridge(ptr: userInfo)
        return player.bassGetOutputData(buffer, length: length)
    }
}

// MARK: Individual Song Decode Stream Callbacks

var bassFileProcs = BASS_FILEPROCS(close: bassFileCloseProc, length: bassLengthProc, read: bassReadProc, seek: bassSeekProc)

func bassLengthProc(userInfo: UnsafeMutableRawPointer?) -> QWORD {
    guard let userInfo = userInfo else { return 0 }
    
    return autoreleasepool {
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        guard let song = bassStream.song, bassStream.fileHandle != nil else { return 0 }
        
        var length = 0
        if bassStream.shouldBreakWaitLoopForever {
            return 0
        } else if song.isFullyCached || bassStream.isTempCached {
            // Return actual file size on disk
            length = song.localFileSize
        } else {
            // Return server reported file size
            length = song.size
        }
        
        DDLogInfo("[bassLengthProc] checking length: \(length) for song: \(song.title)")
        return QWORD(length)
    }
}

func bassReadProc(buffer: UnsafeMutableRawPointer?, length: DWORD, userInfo: UnsafeMutableRawPointer?) -> DWORD {
    guard let userInfo = userInfo, let buffer = buffer else { return 0 }
    
    return autoreleasepool {
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        guard let fileHandle = bassStream.fileHandle else { return 0 }
        
        // Read from the file
        var readData: Data?
        do {
            try ObjC.perform {
                readData = fileHandle.readData(ofLength: Int(length))
            }
        } catch {
            readData = nil
        }
        
        guard let data = readData else { return 0 }
        
        var bytesRead = data.count
        if bytesRead > 0 {
            bytesRead = data.withUnsafeBytes { pointer in
                guard let bytes = pointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                buffer.copyMemory(from: bytes, byteCount: data.count)
                return data.count
            }
        }
        
        if bytesRead < length && bassStream.isSongStarted && !bassStream.wasFileJustUnderrun {
            bassStream.isFileUnderrun = true
        }
        bassStream.wasFileJustUnderrun = false
        return DWORD(bytesRead)
    }
}

func bassSeekProc(offset: QWORD, userInfo: UnsafeMutableRawPointer?) -> ObjCBool {
    guard let userInfo = userInfo else { return false }
    
    return autoreleasepool {
        // Seek to the requested offset (returns false if data not downloaded that far)
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        guard let song = bassStream.song, let fileHandle = bassStream.fileHandle else { return false }
        
        var success = false
        
        // First check the file size to make sure we don't try and skip past the end of the file
        if song.localFileSize >= offset {
            // File size is valid, so assume success unless the seek operation throws an exception
            success = true
            do {
                try fileHandle.seek(toOffset: offset)
            } catch {
                success = false
            }
        }
        
        DDLogInfo("[bassSeekProc] seeking to \(offset) success: \(success)")
        return ObjCBool(success)
    }
}

func bassFileCloseProc(userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else { return }
    
    autoreleasepool {
        let bassStream: BassStream = Bridging.bridge(ptr: userInfo)
        
        // Tell the read wait loop to break in case it's waiting
        bassStream.shouldBreakWaitLoop = true
        bassStream.shouldBreakWaitLoopForever = true
        
        // Close the file handle
        // TODO: implement this - switch to non-deprecated API
        bassStream.fileHandle?.closeFile()
        bassStream.fileHandle = nil
    }
}

// MARK: Seek Fade Callback

func bassSlideSyncProc(handle: HSYNC, channel: DWORD, data: DWORD, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else { return }
    
    // Make sure we're using the right device
    BASS_SetDevice(Bass.outputDeviceNumber)

    autoreleasepool {
        let player: BassGaplessPlayer = Bridging.bridge(ptr: userInfo)
        
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
            guard let nextSong = player.nextSong else { return }
            DDLogInfo("[bassEndSyncProc]  Preparing stream for: \(nextSong)")
            if let nextStream = Bass.prepareStream(song: nextSong, player: player) {
                DDLogInfo("[bassEndSyncProc] Stream prepared successfully for: \(nextSong)")
                synchronized(player.streamQueue) {
                    player.streamQueue.add(nextStream)
                }
                BASS_Mixer_StreamAddChannel(player.mixerStream, nextStream.stream, DWORD(BASS_MIXER_NORAMPIN))
            } else {
                DDLogInfo("[bassEndSyncProc] Could NOT create stream for: \(nextSong)")
                bassStream.isNextSongStreamFailed = true
            }
            
            // Mark as ended and set the buffer space til end for the UI
            bassStream.bufferSpaceTilSongEnd = player.ringBuffer.filledSpaceLength
            bassStream.isEnded = true
        }
    }
}

// MARK: BPM Callback

//func bassBPMProc(handle: HSTREAM, bpm: Float, userInfo: UnsafeMutableRawPointer?) {
//    guard let userInfo = userInfo else { return }
//
//    autoreleasepool {
//        let player: BassGaplessPlayer = Bridging.bridge(ptr: userInfo)
//        player.currentSongBPM = bpm
//    }
//}
