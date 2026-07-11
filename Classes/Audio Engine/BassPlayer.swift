//
//  BassPlayer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/28/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import AVFoundation
import CocoaLumberjackSwift

private let bassStreamRetryDelay = 2.0
private let bassStreamMinFilesizeToFail = 15 * 1024 * 1024 // 15 MB

// TODO: Is it necessary to keep setting BASS_SetDevice all the time?
final class BassPlayer: NSObject {
    private let store: Store
    private let settings: SavedSettings

    // Back-edges (communication cycles) attached weakly at the composition root:
    // the play queue advances on song end, and the stream manager / download queue
    // are only consulted by the underrun wait loop
    private weak var playQueue: PlayQueue?
    private weak var streamManager: StreamManaging?
    private weak var downloadQueue: DownloadQueueing?

    let streamGcdQueue = DispatchQueue(label: "com.isubapp.BassStreamQueue")
    // Serial queue for the underrun wait loop so it never blocks the audio callback thread
    private let underrunWaitQueue = DispatchQueue(label: "com.isubapp.BassUnderrunWaitQueue")

    var streamQueue = [BassStream]()
    let streamQueueSync = NSObject()
    private(set) var outStream: HSTREAM = 0
    private(set) var mixerStream: HSTREAM = 0

    var isPlaying = false
    var waitLoopStream: BassStream?

    // The start offsets are written from the stream GCD queue and read by the save
    // state timer on the main thread, so guard them with a lock
    private let startOffsetsSync = NSObject()
    private var unsafeStartByteOffset = 0
    private var unsafeStartSecondsOffset = 0.0
    var startByteOffset: Int {
        get { synchronized(startOffsetsSync) { unsafeStartByteOffset } }
        set { synchronized(startOffsetsSync) { unsafeStartByteOffset = newValue } }
    }
    var startSecondsOffset: Double {
        get { synchronized(startOffsetsSync) { unsafeStartSecondsOffset } }
        set { synchronized(startOffsetsSync) { unsafeStartSecondsOffset = newValue } }
    }

    var equalizer = BassEqualizer()
    var visualizer = BassVisualizer()

    var retrySongOperation: Operation?
    var shouldResumeFromInterruption = false

    init(store: Store, settings: SavedSettings) {
        self.store = store
        self.settings = settings
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
    }

    func attach(playQueue: PlayQueue) {
        self.playQueue = playQueue
    }

    func attach(streamManager: StreamManaging) {
        self.streamManager = streamManager
    }

    func attach(downloadQueue: DownloadQueueing) {
        self.downloadQueue = downloadQueue
    }
    
    deinit {
        cancelRetrySongOperation()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @discardableResult
    func seekToPosition(seconds: Double, fadeVolume: Bool = true) -> Bool {
        guard let currentStream else { return false }
        
        // Make sure we're using the right device
        BASS_SetDevice(Bass.outputDeviceNumber)
        let bytes = BASS_ChannelSeconds2Bytes(currentStream.hstream, seconds)
        return seekToPosition(bytes: bytes, fadeVolume: fadeVolume)
    }
    
    @discardableResult
    func seekToPosition(bytes: QWORD, fadeVolume: Bool = true) -> Bool {
        guard let currentStream else { return false }
        
        // Make sure we're using the right device
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        guard BASS_Mixer_ChannelSetPosition(currentStream.hstream, bytes, DWORD(BASS_POS_BYTE)) != 0 else {
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
    
    var progress: Double {
        guard let currentStream else { return 0 }
        
        BASS_SetDevice(Bass.outputDeviceNumber)
        let pcmBytePosition = BASS_Mixer_ChannelGetPosition(currentStream.hstream, DWORD(BASS_POS_BYTE))
        let seconds = BASS_ChannelBytes2Seconds(currentStream.hstream, pcmBytePosition < 0 ? 0 : pcmBytePosition)
        return seconds + startSecondsOffset
    }
    
    var isStarted: Bool {
        return (currentStream?.hstream ?? 0) != 0
    }
    
    var currentByteOffset: Int {
        guard let currentStream else { return 0 }
        return Int(BASS_StreamGetFilePosition(currentStream.hstream, DWORD(BASS_FILEPOS_CURRENT))) + startByteOffset
    }
    
    var currentStream: BassStream? {
        synchronized(streamQueueSync) {
            return streamQueue.first
        }
    }
    
    var kiloBitrate: Int {
        guard let currentStream else { return 0 }
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
                if let _ = playQueue?.currentSong {
                    playQueue?.startSong(offsetInBytes: startByteOffset, offsetInSeconds: startSecondsOffset)
                } else {
                    playQueue?.playPrevSong()
                }
            } else {
                BASS_Start()
                isPlaying = true
                NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
            }
        }
    }

    func moveToNextSong() {
        if let _ = playQueue?.nextSong {
            playQueue?.playNextSong()
        } else {
            cleanup()
        }
    }
    
    func initializeOutput() {
        guard mixerStream == 0 && outStream == 0 else { return }
        
        Bass.bassInit()
        
        mixerStream = BASS_Mixer_StreamCreate(Bass.outputSampleRate, 2, DWORD(BASS_STREAM_DECODE))
        outStream = BASS_StreamCreate(Bass.outputSampleRate, 2, 0, bassStreamProc(handle:buffer:length:userInfo:), Bridging.bridge(obj: self))
        
        // Add the slide callback to handle fades
        BASS_ChannelSetSync(outStream, DWORD(BASS_SYNC_SLIDE), 0, bassSlideSyncProc(handle:channel:data:userInfo:), Bridging.bridge(obj: self))
        
        visualizer.channel = outStream
        equalizer.channel = outStream
        
        // Prepare the EQ
        // This will load the values, and if the EQ was previously enabled, will automatically
        // add the EQ values to the stream
        BassEffectDAO(type: .parametricEQ).selectCurrentPreset()
        
        // Add gain amplification
        equalizer.createVolumeFx()
        
        // Add limiter to prevent distortion
        equalizer.createLimiterFx()
        
        equalizer.isPlayerInitialized = true
    }
    
    func cleanup() {
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        cancelRetrySongOperation()
        
        synchronized(streamQueueSync) {
            for bassStream in streamQueue {
                bassStream.shouldBreakWaitLoopForever = true
                BASS_Mixer_ChannelRemove(bassStream.hstream)
                BASS_StreamFree(bassStream.hstream)
            }
            streamQueue.removeAll()
        }
        
        // Clear output buffer
        BASS_ChannelStop(outStream)
        
//        equalizer = BassEqualizer()
//        visualizer = BassVisualizer()
        
        isPlaying = false

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            DDLogError("[BassPlayer] Failed to deactivate audio session for audio playback: \(error)")
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.bassFreed)
    }
    
    func startNewSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double) {
        stop()
        startSong(song, index: index, offsetInBytes: offsetInBytes, offsetInSeconds: offsetInSeconds)
        BassEffectDAO(type: .parametricEQ).selectCurrentPreset()
    }
    
    func startSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            DDLogError("[BassPlayer] Failed to activate audio session for audio playback: \(error)")
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            DDLogError("[BassPlayer] Failed to set audio session category/mode for audio playback: \(error)")
        }
        
        streamGcdQueue.async { [unowned self] in
            BASS_SetDevice(Bass.outputDeviceNumber)
            
            startByteOffset = 0
            startSecondsOffset = 0
            
            cleanup()
            
            guard song.fileExists else { return }
            
            if let bassStream = prepareStream(song: song) {
                BASS_Mixer_StreamAddChannel(mixerStream, bassStream.hstream, DWORD(BASS_MIXER_NORAMPIN))
                BASS_Start()
                
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
                BASS_ChannelPlay(outStream, 0)
                isPlaying = true

                // Notify listeners that playback has started
                NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                
                _ = store.update(playedDate: Date(), song: song)
                
                // Prepare the next song stream if it's available
                prepareNextStream()
            } else if !song.isFullyCached && song.localFileSize < bassStreamMinFilesizeToFail {
                if settings.isOfflineMode {
                    moveToNextSong()
                } else if !song.fileExists {
                    DDLogError("[BassPlayer] Stream for song \(song) failed, file is not on disk, so retrying the song");
                    _ = store.deleteDownloadedSong(song: song)
                    playQueue?.playCurrentSong()
                } else {
                    // Failed to create the stream, retrying
                    DDLogError("[BassPlayer] ------failed to create stream, retrying in 2 seconds------")
                    
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
                playQueue?.playCurrentSong()
            }
        }
    }
    
    func prepareStream(song: Song) -> BassStream? {
        // Make sure we're using the right device
        BASS_SetDevice(Bass.outputDeviceNumber)
        
        if Debug.audioEngine {
            DDLogInfo("[BassPlayer] preparing stream for \(song) file: \(song.currentPath)")
        }
        
        guard song.fileExists else {
            DDLogError("[BassPlayer] failed to create stream because file doesn't exist for song: \(song) file: \(song.currentPath)")
            return nil
        }

        guard let bassStream = BassStream(song: song) else {
            DDLogError("[BassPlayer] failed to create stream because failed to create BassStream object for song: \(song) file: \(song.currentPath)")
            return nil
        }

        func createStream(softwareDecoding: Bool = false) -> HSTREAM {
            var flags = DWORD(BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT)
            if softwareDecoding {
                flags = flags | DWORD(BASS_SAMPLE_SOFTWARE)
            }
            return BASS_StreamCreateFileUser(DWORD(STREAMFILE_NOBUFFER), flags, &bassFileProcs, Bridging.bridge(obj: bassStream))
        }
        
        // Create the stream
        var fileStream = createStream()
        
        // First check if the stream failed because of a BASS_Init error
        if fileStream == 0 && BASS_ErrorGetCode() == BASS_ERROR_INIT {
            // Retry the regular hardware sampling stream
            DDLogError("[BassPlayer] Failed to create stream for \(song) with hardware sampling because BASS is not initialized, initializing BASS and trying again with hardware sampling")
            initializeOutput()
            fileStream = createStream()
        }
        
        if fileStream == 0 {
            DDLogError("[BassPlayer] Failed to create stream for \(song) with hardware sampling, trying again with software sampling")
            Bass.logCurrentError()
            fileStream = createStream(softwareDecoding: true)
        }
        
        guard fileStream != 0 else {
            // Failed to create the stream
            DDLogError("[BassPlayer] failed to create stream for song: \(song) file: \(song.currentPath)")
            Bass.logCurrentError()
            return nil
        }
        
        // Add the stream free callback
        BASS_ChannelSetSync(fileStream, DWORD(BASS_SYNC_END | BASS_SYNC_MIXTIME), 0, bassEndSyncProc, Bridging.bridge(obj: bassStream))
        
        // Ask BASS how many channels are on this stream
        var info = BASS_CHANNELINFO()
        BASS_ChannelGetInfo(fileStream, &info)
        bassStream.channelCount = Int(info.chans)
        bassStream.sampleRate = Int(info.freq)
        
        // Stream successfully created
        bassStream.hstream = fileStream
        bassStream.player = self
        
        // Add stream to queue
        synchronized(streamQueueSync) {
            streamQueue.append(bassStream)
            if Debug.audioEngineStreamQueue {
                DDLogDebug("\n\n[BassPlayer] streamQueue count: \(streamQueue.count)")
                for stream in streamQueue {
                    DDLogDebug("[BassPlayer] \(stream)")
                }
                DDLogDebug("\n\n")
            }
        }

        return bassStream
    }
    
    func prepareNextStream() {
        synchronized(streamQueueSync) {
            guard streamQueue.count == 1, let nextSong = playQueue?.nextSong, nextSong.fileExists else { return }
            _ = prepareStream(song: nextSong)
        }
    }

    func streamReadyToStartPlayback(handler: StreamHandler) {
        guard let playQueue else { return }
        if !isPlaying || handler.isTempCache, let currentSong = playQueue.currentSong, currentSong == handler.song {
            // We were waiting for the current song to download before playing and now it's ready, so start playback
            startNewSong(handler.song, index: playQueue.currentIndex, offsetInBytes: handler.byteOffset, offsetInSeconds: handler.secondsOffset)
        } else if isPlaying, let nextSong = playQueue.nextSong, nextSong == handler.song {
            // The next song is ready to start playback so create the stream
            if streamQueue.count > 1 {
                streamQueue.remove(at: 1)
            }
            prepareNextStream()
        }
    }
    
    func cancelRetrySongOperation() {
        retrySongOperation?.cancel()
        retrySongOperation = nil
    }
    
    // Internal (not private) so tests can invoke it directly: posting a hand-crafted
    // AVAudioSession notification to the notification center also delivers it to the
    // BASS library's own observer, which crashes on non-system notifications
    @objc func handleInterruption(notification: Notification) {
        // The system sends the type/options as NSNumber raw values, so they must be
        // decoded via init(rawValue:) — a direct cast to the enum always fails
        guard let interruptionTypeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else { return }
        
        if interruptionType == .began {
            if Debug.audioEngine {
                DDLogInfo("[BassPlayer] audio session begin interruption")
            }
            
            if isPlaying {
                shouldResumeFromInterruption = true
                pause()
            } else {
                shouldResumeFromInterruption = false
            }
        } else if interruptionType == .ended {
            if Debug.audioEngine {
                DDLogInfo("[BassPlayer] audio session interruption ended, isPlaying: \(isPlaying) isMainThread: \(Thread.isMainThread)")
            }
            
            let interruptionOptionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            if let interruptionOptionsValue = interruptionOptionsValue, AVAudioSession.InterruptionOptions(rawValue: interruptionOptionsValue).contains(.shouldResume) {
                playPause()
            }
            
            // Reset the shouldResumeFromInterruption value
            shouldResumeFromInterruption = false
        }
    }
    
    // Internal for direct invocation from tests, same as handleInterruption
    @objc func handleRouteChange(notification: Notification) {
        // Same NSNumber decoding requirement as handleInterruption
        if let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue), reason == .oldDeviceUnavailable {
            pause()
        }
    }
    
    func bassGetOutputData(buffer: UnsafeMutableRawPointer?, length: DWORD) -> DWORD {
        guard let currentStream else { return 0 }
        
        let bytesRead = BASS_ChannelGetData(mixerStream, buffer, length)
        if bytesRead < length {
            pauseIfUnderrun(bassStream: currentStream)
        }

        return bytesRead
    }
    
    func songEnded(bassStream: BassStream) {
        // Plug in the next stream if available for gapless playback
        synchronized(streamQueueSync) {
            if streamQueue.count > 1 {
                BASS_Mixer_StreamAddChannel(mixerStream, streamQueue[1].hstream, DWORD(BASS_MIXER_NORAMPIN))
            }
        }
        
        // This must be done in the stream GCD queue because if we do it in this thread
        // it will pause the audio output momentarily while it's loading the stream
        streamGcdQueue.async { [unowned self] in
            BASS_SetDevice(Bass.outputDeviceNumber)
            
            autoreleasepool {
                // Increment current playlist index
                playQueue?.incrementIndex()

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
                    if Debug.audioEngine {
                        DDLogInfo("[BassPlayer] songEnded: self.isPlaying = YES")
                    }
                    startSecondsOffset = 0
                    startByteOffset = 0
                    
                    // Send song start notification
                    NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                    
                    // Mark the last played time in the database for cache cleanup
                    _ = store.update(playedDate: Date(), song: bassStream.song)
                }
                
                // If the next song stream was somehow not prepared, prepare it
                prepareNextStream()
            }
        }
    }
    
    private func pauseIfUnderrun(bassStream: BassStream) {
        // Called from the BASS output callback when the mixer returns fewer bytes than
        // requested. A short read from a fully cached song is just the end of the song,
        // and a stream that's already waiting is already being handled.
        guard !bassStream.isWaiting, !bassStream.shouldBreakWaitLoopForever, !bassStream.song.isFullyCached else { return }

        // Get a strong reference to the stream, so that if it's freed while the wait
        // loop is sleeping, the object will still be around to respond to shouldBreakWaitLoop
        waitLoopStream = bassStream

        // Mark the stream as waiting
        bassStream.isWaiting = true
        bassStream.shouldBreakWaitLoop = false

        // The wait loop must not block the audio callback thread
        underrunWaitQueue.async { [weak self] in
            self?.waitForMoreData(bassStream: bassStream)
        }
    }

    private func waitForMoreData(bassStream: BassStream) {
        defer {
            bassStream.isWaiting = false
            bassStream.shouldBreakWaitLoop = false
            if waitLoopStream === bassStream {
                waitLoopStream = nil
            }
        }

        let song = bassStream.song

        if settings.isOfflineMode {
            // This is offline mode and the song can not continue to play
            moveToNextSong()
            return
        }

        // Calculate the needed size:
        // Choose either the current player bitrate, or if for some reason it is not detected properly,
        // use the best estimated bitrate. Then use that to determine how much data to let download to continue.
        let kiloBitrate = Bass.estimateKiloBitrate(bassStream: bassStream)

        // Get the stream handler for this song
        var handler = streamManager?.handler(song: song)
        if handler == nil, downloadQueue?.currentQueuedSong == song {
            handler = downloadQueue?.currentStreamHandler
        }

        // Calculate the bytes to wait based on the recent download speed. If the handler is nil
        // or recent download speed is 0 it will just use the default (currently 10 seconds)
        let bytesToWait = Bass.bytesToBuffer(kiloBitrate: kiloBitrate, bytesPerSec: handler?.recentDownloadSpeedInBytesPerSec ?? 0)
        let neededSize = song.localFileSize + bytesToWait

        if Debug.audioEngine {
            DDLogInfo("[BassPlayer] underrun for \(song), kiloBitrate: \(kiloBitrate), bytesToWait: \(bytesToWait), neededSize: \(neededSize)")
        }

        // Sleep for 10000 microseconds, or 1/100th of a second
        let sleepTimeMicros: useconds_t = 10_000
        // Check file size every second, so 1000000 microseconds
        let fileSizeCheckWaitMicros = 1_000_000
        var totalSleepTimeMicros = 0
        while true {
            // Check if we should break every 100th of a second (breaks on seek/stop/song change)
            usleep(sleepTimeMicros)
            totalSleepTimeMicros += Int(sleepTimeMicros)
            if bassStream.shouldBreakWaitLoop || bassStream.shouldBreakWaitLoopForever {
                break
            }

            // Only check the file size every second
            if totalSleepTimeMicros >= fileSizeCheckWaitMicros {
                totalSleepTimeMicros = 0

                let shouldBreak = autoreleasepool { () -> Bool in
                    if song.localFileSize >= neededSize {
                        // Enough of the file has downloaded to continue
                        return true
                    } else if song.isTempCached && song == streamManager?.lastTempCachedSong {
                        // Handle temp cached songs ending. When they end, they are set as the last temp
                        // cached song, so we know it's done and can stop waiting for data.
                        return true
                    } else if song.isFullyCached {
                        // The song has finished caching, so we can stop waiting
                        return true
                    } else if settings.isOfflineMode {
                        // We entered offline mode while waiting, so no more data is coming
                        moveToNextSong()
                        return true
                    }
                    return false
                }
                if shouldBreak {
                    break
                }
            }
        }

        if Debug.audioEngine {
            DDLogInfo("[BassPlayer] done waiting for more data for \(song)")
        }
    }
}

// Abstraction over the audio player engine so consumers can be unit tested with a fake
// player instead of the real BASS-backed engine (registered in DependencyInjection.swift)
protocol PlayerControlling: AnyObject {
    var isPlaying: Bool { get }
    var isStarted: Bool { get }
    var progress: Double { get }
    var kiloBitrate: Int { get }
    var currentByteOffset: Int { get }
    var currentStream: BassStream? { get }
    var startByteOffset: Int { get set }
    var startSecondsOffset: Double { get set }
    func startNewSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double)
    func pause()
    func playPause()
    func stop()
    @discardableResult func seekToPosition(seconds: Double, fadeVolume: Bool) -> Bool
    func streamReadyToStartPlayback(handler: StreamHandler)
}

extension BassPlayer: PlayerControlling {}
