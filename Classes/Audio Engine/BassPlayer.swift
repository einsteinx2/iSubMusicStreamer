//
//  BassPlayer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/28/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import AVFoundation
import Resolver
import CocoaLumberjackSwift

private let bassStreamRetryDelay = 2.0
private let bassStreamMinFilesizeToFail = 15 * 1024 * 1024 // 15 MB

// TODO: Is it necessary to keep setting BASS_SetDevice all the time?
@objc final class BassPlayer: NSObject {
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var store: Store
    @LazyInjected private var settings: Settings
    @LazyInjected private var social: Social
    @LazyInjected private var streamManager: StreamManager
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: BassPlayer { Resolver.resolve() }
    
    let streamGcdQueue = DispatchQueue(label: "com.isubapp.BassStreamQueue")

    var streamQueue = [BassStream]()
    let streamQueueSync = NSObject()
    var outStream: HSTREAM = 0
    var mixerStream: HSTREAM = 0
    
    @objc var isPlaying = false
    var waitLoopStream: BassStream?
    
    @objc var startByteOffset = 0
    @objc var startSecondsOffset = 0.0
    
    @objc var equalizer = BassEqualizer()
    @objc var visualizer = BassVisualizer()
    
    var retrySongOperation: Operation?
    var shouldResumeFromInterruption = false
    
    override init() {
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
    }
    
    deinit {
        cancelRetrySongOperation()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc @discardableResult
    func seekToPosition(seconds: Double, fadeVolume: Bool = true) -> Bool {
        guard let currentStream = currentStream else { return false }
        
        // Make sure we're using the right device
        BASS_SetDevice(Bass.outputDeviceNumber)
        let bytes = BASS_ChannelSeconds2Bytes(currentStream.hstream, seconds)
        return seekToPosition(bytes: bytes, fadeVolume: fadeVolume)
    }
    
    @objc @discardableResult
    func seekToPosition(bytes: QWORD, fadeVolume: Bool = true) -> Bool {
        guard let currentStream = currentStream else { return false }
        
        // Make sure we're using the right device
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        guard BASS_Mixer_ChannelSetPosition(currentStream.hstream, bytes, DWORD(BASS_POS_BYTE)) else {
            Bass.logCurrentError()
            return false
        }
        
        startByteOffset = Int(bytes)
        
        if (currentStream.isWaiting) {
            currentStream.shouldBreakWaitLoop = true
        }
                
        if (fadeVolume) {
            BASS_ChannelSlideAttribute(outStream, DWORD(BASS_ATTRIB_VOL), 0, Bass.bassOutputBufferLengthMillis)
        }
        
        return true
    }
    
    @objc var progress: Double {
        guard let currentStream = currentStream else { return 0 }
        
        BASS_SetDevice(Bass.outputDeviceNumber)
        let pcmBytePosition = BASS_Mixer_ChannelGetPosition(currentStream.hstream, DWORD(BASS_POS_BYTE))
        let seconds = BASS_ChannelBytes2Seconds(currentStream.hstream, pcmBytePosition < 0 ? 0 : pcmBytePosition)
        return seconds + startSecondsOffset
    }
    
    var isStarted: Bool {
        return (currentStream?.hstream ?? 0) != 0
    }
    
    @objc var currentByteOffset: Int {
        guard let currentStream = currentStream else { return 0 }
        return Int(BASS_StreamGetFilePosition(currentStream.hstream, DWORD(BASS_FILEPOS_CURRENT))) + startByteOffset
    }
    
    var currentStream: BassStream? {
        synchronized(streamQueueSync) {
            return streamQueue.first
        }
    }
    
    @objc var kiloBitrate: Int {
        guard let currentStream = currentStream else { return 0 }
        return Bass.estimateKiloBitrate(bassStream: currentStream)
    }
    
    func stop() {
        BASS_SetDevice(Bass.outputDeviceNumber)
        if isPlaying {
            BASS_Pause()
            isPlaying = false
            NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
        }
        cleanup()
    }
    
    func pause() {
        if isPlaying {
            playPause()
        }
    }
    
    // TODO: Refactor this
    func playPause() {
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        if isPlaying {
            BASS_Pause()
            isPlaying = false
            NotificationCenter.postOnMainThread(name: Notifications.songPlaybackPaused)
        } else {
            if currentStream == nil {
                // See if we're at the end of the playlist
                if let _ = playQueue.currentSong {
                    playQueue.startSong(offsetInBytes: startByteOffset, offsetInSeconds: startSecondsOffset)
                } else {
                    playQueue.playPrevSong()
                }
            } else {
                BASS_Start()
                isPlaying = true
                NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
            }
        }
        
        playQueue.updateLockScreenInfo()
    }
    
    func moveToNextSong() {
        if let _ = playQueue.nextSong {
            playQueue.playNextSong()
        } else {
            cleanup()
        }
    }
    
    func cleanup() {
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        synchronized(visualizer) {
            cancelRetrySongOperation()
            
            synchronized(streamQueueSync) {
                for bassStream in streamQueue {
                    bassStream.shouldBreakWaitLoopForever = true
                    BASS_StreamFree(bassStream.hstream)
                }
            }
            
            BASS_StreamFree(mixerStream)
            BASS_StreamFree(outStream)
            
            equalizer = BassEqualizer()
            visualizer = BassVisualizer()
            
            isPlaying = false
            
            social.playerClearSocial()
            
            synchronized(streamQueueSync) {
                streamQueue.removeAll()
            }
            
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                DDLogError("[BassGaplessPlayer] Failed to deactivate audio session for audio playback: \(error)")
            }
            
            NotificationCenter.postOnMainThread(name: Notifications.bassFreed)
        }
    }
    
    func startNewSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double) {
        stop()
        startSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
        let effectDAO = BassEffectDAO(type: BassEffectType_ParametricEQ)!
        effectDAO.selectPreset(at: effectDAO.selectedPresetId)
    }
    
    func startSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            DDLogError("[BassGaplessPlayer] Failed to activate audio session for audio playback: \(error)")
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            DDLogError("[BassGaplessPlayer] Failed to set audio session category/mode for audio playback: \(error)")
        }
        
        streamGcdQueue.async { [unowned self] in
            BASS_SetDevice(Bass.outputDeviceNumber)
            
            startByteOffset = 0
            startSecondsOffset = 0
            
            cleanup()
            
            guard song.fileExists else { return }
            
            let bassStream = Bass.prepareStream(song: song, player: self)
            if let bassStream = bassStream {
                mixerStream = BASS_Mixer_StreamCreate(Bass.outputSampleRate, 2, DWORD(BASS_STREAM_DECODE))
                BASS_Mixer_StreamAddChannel(mixerStream, bassStream.hstream, DWORD(BASS_MIXER_NORAMPIN))
                outStream = BASS_StreamCreate(Bass.outputSampleRate, 2, 0, bassStreamProc(handle:buffer:length:userInfo:), Bridging.bridge(obj: self))
                
                BASS_Start()
                
                // Add the slide callback to handle fades
                BASS_ChannelSetSync(outStream, DWORD(BASS_SYNC_SLIDE), 0, bassSlideSyncProc(handle:channel:data:userInfo:), Bridging.bridge(obj: self))
                
                visualizer.channel = outStream
                equalizer.channel = outStream
                
                // Prepare the EQ
                // This will load the values, and if the EQ was previously enabled, will automatically
                // add the EQ values to the stream
                let effectDAO = BassEffectDAO(type: BassEffectType_ParametricEQ)!
                effectDAO.selectPreset(at: effectDAO.selectedPresetId)
                
                // Add gain amplification
                equalizer.createVolumeFx()
                
                // Add limiter to prevent distortion
                equalizer.createLimiterFx()
                
                // Add the stream to the queue
                synchronized(streamQueueSync) {
                    streamQueue.append(bassStream)
                }
                
                if song.isTempCached {
                    // If temp cached, just set the offset but don't actually seek
                    startByteOffset = offsetInBytes
                    startSecondsOffset = offsetInSeconds
                } else {
                    // Skip to the byte offset
                    if offsetInBytes > 0 {
                        startByteOffset = offsetInBytes
                        if offsetInSeconds > 0 {
                            seekToPosition(seconds: offsetInSeconds, fadeVolume: false)
                        } else {
                            seekToPosition(bytes: QWORD(offsetInBytes), fadeVolume: false)
                        }
                    } else if offsetInSeconds > 0 {
                        startSecondsOffset = offsetInSeconds
                        seekToPosition(seconds: offsetInSeconds, fadeVolume: false)
                    }
                }
                
                // Start playback
                BASS_ChannelPlay(outStream, false)
                isPlaying = true
                
                social.playerClearSocial()
                
                playQueue.updateLockScreenInfo()
                
                // Notify listeners that playback has started
                NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                
                _ = store.update(playedDate: Date(), song: song)
            } else if !song.isFullyCached && song.localFileSize < bassStreamMinFilesizeToFail {
                if settings.isOfflineMode {
                    moveToNextSong()
                } else if !song.fileExists {
                    DDLogError("[BassGaplessPlayer] Stream for song \(song) failed, file is not on disk, so retrying the song");
                    _ = store.deleteDownloadedSong(song: song)
                    playQueue.playCurrentSong()
                } else {
                    // Failed to create the stream, retrying
                    DDLogError("[BassGaplessPlayer] ------failed to create stream, retrying in 2 seconds------")
                    
                    cancelRetrySongOperation()
                    
                    retrySongOperation = BlockOperation { [unowned self] in
                        startSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
                    }
                    
                    DispatchQueue.main.async(after: bassStreamRetryDelay) { [unowned self] in
                        if let operation = retrySongOperation, !operation.isFinished && !operation.isCancelled {
                            OperationQueue.main.addOperation(operation)
                        }
                    }
                }
            } else {
                _ = store.deleteDownloadedSong(song: song)
                playQueue.playCurrentSong()
            }
        }
    }
    
    func cancelRetrySongOperation() {
        retrySongOperation?.cancel()
        retrySongOperation = nil
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let interruptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType else { return }
        
        if interruptionType == .began {
            DDLogInfo("[BassGaplessPlayer] audio session begin interruption")
            if isPlaying {
                shouldResumeFromInterruption = true
                pause()
            } else {
                shouldResumeFromInterruption = false
            }
        } else if interruptionType == .ended {
            DDLogInfo("[BassGaplessPlayer] audio session interruption ended, isPlaying: \(isPlaying) isMainThread: \(Thread.isMainThread)")
            let interruptionOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? AVAudioSession.InterruptionOptions
            if let interruptionOptions = interruptionOptions, interruptionOptions == .shouldResume {
                playPause()
            }
            
            // Reset the shouldResumeFromInterruption value
            shouldResumeFromInterruption = false
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason, reason == .oldDeviceUnavailable {
            pause()
        }
    }
    
    func bassGetOutputData(buffer: UnsafeMutableRawPointer?, length: DWORD) -> DWORD {
        social.playerHandleSocial()
        
        guard let currentStream = currentStream else { return 0 }
        
        let bytesRead = BASS_ChannelGetData(mixerStream, buffer, length)
        if bytesRead < length {
            pauseIfUnderrun(bassStream: currentStream)
        }
        
        if currentStream.isEnded {
            songEnded(bassStream: currentStream)
        }
        
        if bytesRead == 0 && BASS_ChannelIsActive(currentStream.hstream) == 0 && (currentStream.song.isFullyCached || currentStream.song.isTempCached) {
            isPlaying = false
            
            if !currentStream.isEndedCalled {
                // Somehow songEnded: was never called
                songEnded(bassStream: currentStream)
            }
            
            // The stream should end, because there is no more music to play
            NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
            
            DDLogInfo("[BassGaplessPlayer] Stream not active, freeing BASS")
            DispatchQueue.main.async {
                self.cleanup()
            }
            
            // Start the next song if for some reason this one isn't ready
            playQueue.playCurrentSong()
            return BASS_STREAMPROC_END
        }
        
        return bytesRead
    }
    
    // songEnded: is called AFTER MyStreamEndCallback, so the next song is already actually decoding into the ring buffer
    func songEnded(bassStream: BassStream) {
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        autoreleasepool {
            bassStream.isEndedCalled = true
            
            // Increment current playlist index
            playQueue.incrementIndex()
            
            // Clear the social post status
            social.playerClearSocial()
            
            playQueue.updateLockScreenInfo()
            
            // Remove the stream from the queue
            BASS_StreamFree(bassStream.hstream)
            synchronized(streamQueueSync) {
                streamQueue.removeAll { $0 == bassStream }
            }
            
            // Instead wait for the playlist index changed notification
            /*// Update our index position
            self.currentPlaylistIndex = [self nextIndex];*/
            
            // Send song end notification
            NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
            
            if isPlaying {
                DDLogInfo("[BassGaplessPlayer] songEnded: self.isPlaying = YES")
                startSecondsOffset = 0
                startByteOffset = 0
                
                // Send song start notification
                NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                
                // Mark the last played time in the database for cache cleanup
                _ = store.update(playedDate: Date(), song: bassStream.song)
            }
            
            if bassStream.isNextSongStreamFailed {
                DispatchQueue.main.async {
                    // The song ended, and we tried to make the next stream but it failed
                    if let song = self.playQueue.song(index: self.playQueue.currentIndex), let handler = self.streamManager.handler(song: song) {
                        if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
                            // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                            self.playQueue.playCurrentSong()
                        }
                    }
                }
            }
        }
    }
    
    private func pauseIfUnderrun(bassStream: BassStream) {
        return
        
        /*
         * Handle pausing to wait for more data
         */
        /*
            //    if (userInfo.isFileUnderrun && BASS_ChannelIsActive(userInfo.stream)) {
                    // Get a strong reference to the current song's userInfo object, so that
                    // if the stream is freed while the wait loop is sleeping, the object will
                    // still be around to respond to shouldBreakWaitLoop
                    self.waitLoopStream = userInfo;

                    // Mark the stream as waiting
                    userInfo.isWaiting = YES;
            //        userInfo.isFileUnderrun = NO;
            //        userInfo.wasFileJustUnderrun = YES;

                    // Handle waiting for additional data
                    ISMSSong *theSong = userInfo.song;
                    if (!theSong.isFullyCached) {
                        if (settingsS.isOfflineMode) {
                            // This is offline mode and the song can not continue to play
                            [self moveToNextSong];
                        } else {
                            // Calculate the needed size:
                            // Choose either the current player bitrate, or if for some reason it is not detected properly,
                            // use the best estimated bitrate. Then use that to determine how much data to let download to continue.

                            NSInteger size = theSong.localFileSize;
                            NSInteger bitrate = [Bass estimateKiloBitrateWithBassStream:userInfo];

                            // Get the stream for this song
                            StreamHandler *handler = [StreamManager.shared handlerWithSong:userInfo.song];
                            if (!handler && [CacheQueue.shared.currentQueuedSong isEqual:userInfo.song])
                                handler = [CacheQueue.shared currentStreamHandler];

                            // Calculate the bytes to wait based on the recent download speed. If the handler is nil or recent download speed is 0
                            // it will just use the default (currently 10 seconds)
                            NSInteger bytesToWait = [Bass bytesToBufferWithKiloBitrate:bitrate bytesPerSec:handler.recentDownloadSpeedInBytesPerSec];

                            NSInteger neededSize = size + bytesToWait;

                            DDLogInfo(@"[BassGaplessPlayer] AUDIO ENGINE - calculating wait, bitrate: %ld, recentBytesPerSec: %ld, bytesToWait: %ld", (long)bitrate, (long)handler.recentDownloadSpeedInBytesPerSec, (long)bytesToWait);
                            DDLogInfo(@"[BassGaplessPlayer] AUDIO ENGINE - waiting for %ld, neededSize: %ld", (long)bytesToWait, (long)neededSize);

                            // Sleep for 10000 microseconds, or 1/100th of a second
                            static const QWORD sleepTime = 10000;
                            // Check file size every second, so 1000000 microseconds
                            static const QWORD fileSizeCheckWait = 1000000;
                            QWORD totalSleepTime = 0;
                            while (YES) {
                                // Bail if the thread was canceled
                                if (NSThread.currentThread.isCancelled) break;

                                // Check if we should break every 100th of a second
                                usleep(sleepTime);
                                totalSleepTime += sleepTime;
                                if (userInfo.shouldBreakWaitLoop || userInfo.shouldBreakWaitLoopForever) break;

                                // Bail if the thread was canceled
                                if (NSThread.currentThread.isCancelled) break;

                                // Only check the file size every second
                                if (totalSleepTime >= fileSizeCheckWait) {
                                    @autoreleasepool {
                                        totalSleepTime = 0;

                                        // If enough of the file has downloaded, break the loop
                                        if (userInfo.sizeOnDisk >= neededSize) {
                                            break;
                                        // Handle temp cached songs ending. When they end, they are set as the last temp cached song, so we know it's done and can stop waiting for data.
                                        } else if (theSong.isTempCached && [theSong isEqual:StreamManager.shared.lastTempCachedSong]) {
                                            break;
                                        // If the song has finished caching, we can stop waiting
                                        } else if (theSong.isFullyCached) {
                                            break;
                                        // If we're not in offline mode, stop waiting and try next song
                                        } else if (settingsS.isOfflineMode) {
                                            // Bail if the thread was canceled
                                            if (NSThread.currentThread.isCancelled) break;

                                            [self moveToNextSong];
                                            break;
                                        }
                                    }
                                }
                            }
                            DDLogInfo(@"[BassGaplessPlayer] done waiting");
                        }
                    }

                    userInfo.isWaiting = NO;
                    userInfo.shouldBreakWaitLoop = NO;
                    self.waitLoopStream = nil;
            //    }
 */
    }
}
