//
//  BassGaplessPlayer.m
//  iSub
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassGaplessPlayer.h"
#import "SavedSettings.h"
#import "EX2RingBuffer.h"
#import "EX2Dispatch.h"
#import "Defines.h"
#import "Swift.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <AVFoundation/AVFoundation.h>

@interface BassGaplessPlayer ()
@property (strong) NSObject<BassGaplessPlayerDelegate> *defaultDelegate;
@property (strong) NSOperation *retrySongOperation;
@property BOOL shouldResumeFromInterruption;
@end

@implementation BassGaplessPlayer

LOG_LEVEL_ISUB_DEFAULT

#define ISMS_BassDeviceNumber 1

#define ISMS_BASSBufferSize 800
#define ISMS_defaultSampleRate 44100

// Stream create failure retry values
#define ISMS_BassStreamRetryDelay 2.0
#define ISMS_BassStreamMinFilesizeToFail 15*1024*1024

#define startSongRetryTimer @"startSong"

+ (instancetype)shared {
    static BassGaplessPlayer *shared = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
	if (self = [super init]) {
        _defaultDelegate = [[BassPlayerDelegate alloc] init];
        _delegate = _defaultDelegate;
		_streamQueue = [NSMutableArray arrayWithCapacity:5];
		_streamGcdQueue = dispatch_queue_create("com.isubapp.BassStreamQueue", NULL);
		_ringBuffer = [EX2RingBuffer ringBufferWithLength:640 * 1024];
        
        _equalizer = [[BassEqualizer alloc] init];
        _visualizer = [[BassVisualizer alloc] init];
		
		// Keep track of the playlist index
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(updatePlaylistIndex:) name:Notifications.currentPlaylistOrderChanged object:nil];
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(updatePlaylistIndex:) name:Notifications.currentPlaylistIndexChanged object:nil];
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(updatePlaylistIndex:) name:Notifications.currentPlaylistShuffleToggled object:nil];
        
        // Audio session callbacks
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:AVAudioSession.sharedInstance];
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:AVAudioSession.sharedInstance];
	}
	
    return self;
}

- (void)dealloc {
    [self cancelRetrySongOperation];
	[NSNotificationCenter removeObserverOnMainThread:self];
}

#pragma mark Audio Session Callbacks

- (void)handleInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        DDLogVerbose(@"[BassGaplessPlayer] audio session begin interruption");
        if (self.isPlaying) {
            self.shouldResumeFromInterruption = YES;
            [self pause];
        } else {
            self.shouldResumeFromInterruption = NO;
        }
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
        DDLogVerbose(@"[BassGaplessPlayer] audio session interruption ended, isPlaying: %@ isMainThread: %@", NSStringFromBOOL(self.isPlaying), NSStringFromBOOL(NSThread.isMainThread));
        AVAudioSessionInterruptionOptions interruptionOptions = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (self.shouldResumeFromInterruption && interruptionOptions == AVAudioSessionInterruptionOptionShouldResume) {
            [self playPause];
        }
        
        // Reset the shouldResumeFromInterruption value
        self.shouldResumeFromInterruption = NO;
    }
}

- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSessionRouteChangeReason reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        [self pause];
    }
}

#pragma mark Decode Stream Callbacks

void CALLBACK MyStreamSlideCallback(HSYNC handle, DWORD channel, DWORD data, void *user) {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);

	@autoreleasepool {
        BassGaplessPlayer *player = (__bridge BassGaplessPlayer *)user;

        float volumeLevel;
        BOOL success = BASS_ChannelGetAttribute(player.outStream, BASS_ATTRIB_VOL, &volumeLevel);

        if (success && volumeLevel == 0.0) {
            BASS_ChannelSlideAttribute(player.outStream, BASS_ATTRIB_VOL, 1, 200);
        }
    }
}

#pragma mark - Output Stream

DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user) {
	@autoreleasepool {
		BassGaplessPlayer *player = (__bridge BassGaplessPlayer *)user;
		return [player bassGetOutputData:buffer length:length];
	}
}

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length {
	if ([self.delegate respondsToSelector:@selector(bassRetrievingOutputData:)]) {
        [self.delegate bassRetrievingOutputData:self];
    }
    
	BassStream *userInfo = self.currentStream;
	NSInteger bytesRead = [self.ringBuffer drainBytes:buffer length:length];
	
	if (userInfo.isEnded) {
		userInfo.bufferSpaceTilSongEnd -= bytesRead;
		if (userInfo.bufferSpaceTilSongEnd <= 0) {
			[self songEnded:userInfo];
		}
	}
    
    ISMSSong *currentSong = userInfo.song;
	if (!currentSong || (bytesRead == 0 && !BASS_ChannelIsActive(userInfo.stream) && (currentSong.isFullyCached || currentSong.isTempCached))) {
		self.isPlaying = NO;
		
		if (!userInfo.isEndedCalled) {
			// Somehow songEnded: was never called
			[userInfo.player songEnded:userInfo];
		}
		
		// The stream should end, because there is no more music to play
		[NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackEnded object:nil userInfo:nil];
		
        DDLogInfo(@"[BassGaplessPlayer] Stream not active, freeing BASS");
        [EX2Dispatch runInMainThreadAsync:^{
            [self cleanup];
        }];
		
		// Start the next song if for some reason this one isn't ready
        [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
		return BASS_STREAMPROC_END;
    }
	return (DWORD)bytesRead;
}

- (void)moveToNextSong {
	if (self.nextSong) {
        [self.delegate bassRetrySongAtIndex:self.nextIndex player:self];
	} else {
		[self cleanup];
	}
}

// songEnded: is called AFTER MyStreamEndCallback, so the next song is already actually decoding into the ring buffer
- (void)songEnded:(BassStream *)userInfo {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@autoreleasepool {
        self.previousSongForProgress = userInfo.song;
        self.ringBuffer.totalBytesDrained = 0;
        
		userInfo.isEndedCalled = YES;
        
        // The delegate is responsible for incrementing the playlist index
        if ([self.delegate respondsToSelector:@selector(bassSongEndedCalled:)]) {
            [self.delegate bassSongEndedCalled:self];
        }
        
        if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)]) {
            [self.delegate bassUpdateLockScreenInfo:self];
        }
		
		// Remove the stream from the queue
		if (userInfo) {
			BASS_StreamFree(userInfo.stream);
		}
        @synchronized(self.streamQueue) {
            [self.streamQueue removeObject:userInfo];
        }
        
        // Instead wait for the playlist index changed notification
        /*// Update our index position
        self.currentPlaylistIndex = [self nextIndex];*/

		// Send song end notification
		[NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackEnded object:nil userInfo:nil];
		
		if (self.isPlaying) {
			DDLogInfo(@"[BassGaplessPlayer] songEnded: self.isPlaying = YES");
			self.startSecondsOffset = 0;
			self.startByteOffset = 0;
			
			// Send song start notification
			[NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackStarted object:nil userInfo:nil];
            
            // Mark the last played time in the database for cache cleanup
            (void)[Store.shared updateWithPlayedDate:[NSDate date] song:self.currentStream.song];
		}

        if (userInfo.isNextSongStreamFailed) {
            if ([self.delegate respondsToSelector:@selector(bassFailedToCreateNextStreamForIndex:player:)]) {
                [EX2Dispatch runInMainThreadAsync:^{
                    [self.delegate bassFailedToCreateNextStreamForIndex:self.currentPlaylistIndex player:self];
                }];
            }
        }
	}
}

- (void)keepRingBufferFilled {
    // Cancel the existing thread if needed
    [self.ringBufferFillThread cancel];
    
    // Create and start a new thread to fill the buffer
    self.ringBufferFillThread = [[NSThread alloc] initWithTarget:self selector:@selector(keepRingBufferFilledInternal) object:nil];
    self.ringBufferFillThread.name = @"BASS Ring buffer fill thread";
	[self.ringBufferFillThread start];
}

- (void)keepRingBufferFilledInternal {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
    // Grab the mixerStream and ringBuffer as local references, so that if cleanup is run, and we're still inside this loop
    // it won't start filling the new buffer
    EX2RingBuffer *localRingBuffer = self.ringBuffer;
    HSTREAM localMixerStream = self.mixerStream;
    
	@autoreleasepool {
		NSInteger readSize = 64 * 1024;
		while (!NSThread.currentThread.isCancelled) {
			// Fill the buffer if there is empty space
			if (localRingBuffer.freeSpaceLength > readSize) {
				@autoreleasepool  {
                    /*
                     * Read data to fill the buffer
                     */
                    
                    BassStream *userInfo = self.currentStream;
                    
                    void *tempBuffer = malloc(sizeof(char) * readSize);
                    DWORD tempLength = BASS_ChannelGetData(localMixerStream, tempBuffer, (DWORD)readSize);
                    if (tempLength) {
                        userInfo.isSongStarted = YES;
                        [localRingBuffer fillWithBytes:tempBuffer length:tempLength];
                    }
                    free(tempBuffer);
                    
                    /*
                     * Handle pausing to wait for more data
                     */
                    
                    if (userInfo.isFileUnderrun && BASS_ChannelIsActive(userInfo.stream)) {
                        // Get a strong reference to the current song's userInfo object, so that
                        // if the stream is freed while the wait loop is sleeping, the object will
                        // still be around to respond to shouldBreakWaitLoop
                        self.waitLoopStream = userInfo;
                        
                        // Mark the stream as waiting
                        userInfo.isWaiting = YES;
                        userInfo.isFileUnderrun = NO;
                        userInfo.wasFileJustUnderrun = YES;
                        
                        // Handle waiting for additional data
                        ISMSSong *theSong = userInfo.song;
                        if (!theSong.isFullyCached) {
                            // Bail if the thread was canceled
                            if (NSThread.currentThread.isCancelled) break;
                            
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
                                                                    
                                userInfo.neededSize = size + bytesToWait;
                                
                                DDLogInfo(@"[BassGaplessPlayer] AUDIO ENGINE - calculating wait, bitrate: %ld, recentBytesPerSec: %ld, bytesToWait: %ld", (long)bitrate, (long)handler.recentDownloadSpeedInBytesPerSec, (long)bytesToWait);
                                DDLogInfo(@"[BassGaplessPlayer] AUDIO ENGINE - waiting for %ld, neededSize: %ld", (long)bytesToWait, (long)userInfo.neededSize);
                                
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
                                            if (userInfo.localFileSize >= userInfo.neededSize) {
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
                        
                        // Bail if the thread was canceled
                        if (NSThread.currentThread.isCancelled) break;
                        
                        userInfo.isWaiting = NO;
                        userInfo.shouldBreakWaitLoop = NO;
                        self.waitLoopStream = nil;
                    }
				}
			}
            
            // Bail if the thread was canceled
            if (NSThread.currentThread.isCancelled) break;
			
			// Sleep for 1/4th of a second to prevent a tight loop
			usleep(150000);
		}
	}
}

#pragma mark - BASS methods

- (void)cleanup {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@synchronized(self.visualizer) {
        [self cancelRetrySongOperation];
		[self.ringBufferFillThread cancel];
		
        @synchronized(self.streamQueue) {
            for (BassStream *userInfo in self.streamQueue) {
                userInfo.shouldBreakWaitLoopForever = YES;
                BASS_StreamFree(userInfo.stream);
            }
        }
        
        BASS_StreamFree(self.mixerStream);
        BASS_StreamFree(self.outStream);
		
		self.equalizer = [[BassEqualizer alloc] init];
        self.visualizer = [[BassVisualizer alloc] init];
		
		self.isPlaying = NO;
		
		[self.ringBuffer reset];
		
        if ([self.delegate respondsToSelector:@selector(bassFreed:)]) {
            [self.delegate bassFreed:self];
        }

        @synchronized(self.streamQueue) {
            [self.streamQueue removeAllObjects];
        }
        
        NSError *audioSessionError = nil;
        [AVAudioSession.sharedInstance setActive:NO error:&audioSessionError];
        if (audioSessionError) {
            DDLogError(@"[BassGaplessPlayer] Failed to deactivate audio session for audio playback: %@", audioSessionError.localizedDescription);
        }
		
		[NSNotificationCenter postOnMainThreadWithName:Notifications.bassFreed object:nil userInfo:nil];
	}
}

- (BOOL)testStreamForSong:(ISMSSong *)aSong {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
    DDLogInfo(@"[BassGaplessPlayer] testing stream for %@  file: %@", aSong.title, aSong.currentPath);
	if (aSong.fileExists) {
		// Create the stream
        HSTREAM fileStream = BASS_StreamCreateFile(NO, [aSong.currentPath cStringUsingEncoding:NSUTF8StringEncoding], 0, aSong.size, BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT);
		if (!fileStream) {
            fileStream = BASS_StreamCreateFile(NO, [aSong.currentPath cStringUsingEncoding:NSUTF8StringEncoding], 0, aSong.size, BASS_STREAM_DECODE|BASS_SAMPLE_SOFTWARE|BASS_SAMPLE_FLOAT);
        }
        
		if (fileStream) {
			return YES;
		}
		
		// Failed to create the stream
		DDLogError(@"[BassGaplessPlayer] failed to create test stream for song: %@  filename: %@", aSong.title, aSong.currentPath);
		return NO;
	}
	
	// File doesn't exist
    return NO;
}

- (void)startNewSong:(ISMSSong *)aSong atIndex:(NSInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds {
    // Stop the player
    [self stop];
    
    // Start the new song
    [self startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds];
    
    // Load the EQ
    BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    [effectDAO selectPresetId:effectDAO.selectedPresetId];
}

- (void)startSong:(ISMSSong *)aSong atIndex:(NSInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds {
    if (!aSong) return;
    
    NSError *audioSessionError = nil;
    [AVAudioSession.sharedInstance setActive:YES error:&audioSessionError];
    if (audioSessionError) {
        DDLogError(@"[BassGaplessPlayer] Failed to activate audio session for audio playback: %@", audioSessionError.localizedDescription);
    }
    
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&audioSessionError];
    if (audioSessionError) {
        DDLogError(@"[BassGaplessPlayer] Failed to set audio session category/mode for audio playback: %@", audioSessionError.localizedDescription);
    }
    
	[EX2Dispatch runInQueue:_streamGcdQueue waitUntilDone:NO block:^{
        // Make sure we're using the right device
        BASS_SetDevice(ISMS_BassDeviceNumber);
        
        self.currentPlaylistIndex = index;
        
        self.startByteOffset = 0;
        self.startSecondsOffset = 0;
        
        [self cleanup];
        
        if (aSong.fileExists) {
            BassStream *userInfo = [Bass prepareStreamWithSong:aSong player:self];
            if (userInfo) {
                self.mixerStream = BASS_Mixer_StreamCreate(ISMS_defaultSampleRate, 2, BASS_STREAM_DECODE);//|BASS_MIXER_END);
                BASS_Mixer_StreamAddChannel(self.mixerStream, userInfo.stream, BASS_MIXER_NORAMPIN);
                self.outStream = BASS_StreamCreate(ISMS_defaultSampleRate, 2, 0, &MyStreamProc, (__bridge void*)self);
                
                self.ringBuffer.totalBytesDrained = 0;
                
                BASS_Start();
                
                // Add the slide callback to handle fades
                BASS_ChannelSetSync(self.outStream, BASS_SYNC_SLIDE, 0, MyStreamSlideCallback, (__bridge void*)self);
                
                self.visualizer.channel = self.outStream;
                self.equalizer.channel = self.outStream;
                
                // Prepare the EQ
                // This will load the values, and if the EQ was previously enabled, will automatically
                // add the EQ values to the stream
                BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
                [effectDAO selectPresetId:effectDAO.selectedPresetId];
                
                // Add gain amplification
                [self.equalizer createVolumeFx];
                
                // Add limiter to prevent distortion
                [self.equalizer createLimiterFx];
                
                // Add the stream to the queue
                @synchronized(self.streamQueue) {
                    [self.streamQueue addObject:userInfo];
                }
                
                if (aSong.isTempCached) {
                    // If temp cached, just set the offset but don't actually seek
                    self.startByteOffset = (NSInteger)byteOffset.unsignedLongLongValue;
                    self.startSecondsOffset = seconds.doubleValue;
                } else {
                    // Skip to the byte offset
                    if (byteOffset) {
                        self.startByteOffset = (NSInteger)byteOffset.unsignedLongLongValue;
                        self.ringBuffer.totalBytesDrained = byteOffset.unsignedLongLongValue;
                        
                        if (seconds) {
                            [self seekToPositionInSeconds:seconds.doubleValue fadeVolume:NO];
                        } else if (self.startByteOffset > 0) {
                            [self seekToPositionInBytes:self.startByteOffset fadeVolume:NO];
                        }
                    } else if (seconds) {
                        self.startSecondsOffset = seconds.doubleValue;
                        if (self.startSecondsOffset > 0.0) {
                            [self seekToPositionInSeconds:self.startSecondsOffset fadeVolume:NO];
                        }
                    }
                }
                
                // Start filling the ring buffer
                [self keepRingBufferFilled];
                
                // Start playback
                BASS_ChannelPlay(self.outStream, FALSE);
                self.isPlaying = YES;

                if ([self.delegate respondsToSelector:@selector(bassFirstStreamStarted:)]) {
                    [self.delegate bassFirstStreamStarted:self];
                }
                
                if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)]) {
                    [self.delegate bassUpdateLockScreenInfo:self];
                }
                
                // Notify listeners that playback has started
                [NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackStarted object:nil userInfo:nil];
                
                (void)[Store.shared updateWithPlayedDate:[NSDate date] song:aSong];
            } else if (!userInfo && !aSong.isFullyCached && aSong.localFileSize < ISMS_BassStreamMinFilesizeToFail) {
                if (settingsS.isOfflineMode) {
                    [self moveToNextSong];
                } else if (!aSong.fileExists) {
                    DDLogError(@"[BassGaplessPlayer] Stream for song %@ failed, file is not on disk, so calling retrying the song", userInfo.song.title);
                    // File was removed, most likely because the decryption failed, so start again normally
                    (void)[aSong removeFromDownloads];
                    [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
                } else {
                    // Failed to create the stream, retrying
                    DDLogError(@"[BassGaplessPlayer] ------failed to create stream, retrying in 2 seconds------");
                    
                    [self cancelRetrySongOperation];
                    
                    __weak BassGaplessPlayer *weakSelf = self;
                    self.retrySongOperation = [NSBlockOperation blockOperationWithBlock:^{
                        [weakSelf startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds];
                    }];
                    
                    __weak NSOperation *weakOperation = self.retrySongOperation;
                    [EX2Dispatch runInMainThreadAfterDelay:ISMS_BassStreamRetryDelay block:^{
                        if (weakOperation && !weakOperation.isFinished && !weakOperation.isCancelled) {
                            [[NSOperationQueue mainQueue] addOperation:weakOperation];
                        }
                    }];
                }
            } else {
                (void)[aSong removeFromDownloads];
                [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
            }
        }
    }];
}

- (void)cancelRetrySongOperation {
    [self.retrySongOperation cancel];
    self.retrySongOperation = nil;
}

- (NSInteger)nextIndex {
    return [self.delegate bassIndexAtOffset:1 fromIndex:self.currentPlaylistIndex player:self];
}

- (ISMSSong *)nextSong {
    return [self.delegate bassSongForIndex:[self nextIndex] player:self];
}

// Called via a notification whenever the playlist index changes
- (void)updatePlaylistIndex:(NSNotification *)notification {
    self.currentPlaylistIndex = [self.delegate bassCurrentPlaylistIndex:self];
    DDLogInfo(@"[BassGaplessPlayer] Updating playlist index to: %lu", (unsigned long)self.currentPlaylistIndex);
}

#pragma mark Audio Engine Properties

- (BOOL)isStarted {
	return self.currentStream.stream != 0;
}

- (NSInteger)currentByteOffset {
	return BASS_StreamGetFilePosition(self.currentStream.stream, BASS_FILEPOS_CURRENT) + self.startByteOffset;
}

- (double)progress {
	if (!self.currentStream)
		return 0;
	
    NSInteger pcmBytePosition = BASS_Mixer_ChannelGetPosition(self.currentStream.stream, BASS_POS_BYTE);
    
    NSInteger chanCount = self.currentStream.channelCount;
    double denom = (2 * (1 / (double)chanCount));
    NSInteger realPosition = pcmBytePosition - ((double)self.ringBuffer.filledSpaceLength / denom);
    
    //ALog(@"adjustedPosition: %lli, pcmBytePosition: %lli, self.ringBuffer.filledSpaceLength: %i", realPosition, pcmBytePosition, self.ringBuffer.filledSpaceLength);
    
    double sampleRateRatio = self.currentStream.sampleRate / (double)ISMS_defaultSampleRate;
	
    //ALog(@"total bytes drained: %lli, seconds: %f, sampleRate: %li, ratio: %f", self.ringBuffer.totalBytesDrained, BASS_ChannelBytes2Seconds(self.currentStream.stream, self.ringBuffer.totalBytesDrained * sampleRateRatio * chanCount), (long)self.currentStream.sampleRate, sampleRateRatio);
    pcmBytePosition = realPosition;
	pcmBytePosition = pcmBytePosition < 0 ? 0 : pcmBytePosition; 
	//double seconds = BASS_ChannelBytes2Seconds(self.currentStream.stream, pcmBytePosition);
    double seconds = BASS_ChannelBytes2Seconds(self.currentStream.stream, self.ringBuffer.totalBytesDrained * sampleRateRatio * chanCount);
    //ALog(@"seconds: %f", seconds);
    //DDLogVerbose(@"[BassGaplessPlayer] progress seconds: %f", seconds);
	if (seconds < 0)
    {
        // Use the previous song (i.e the one still coming out of the speakers), since we're actually finishing it right now
        /*NSInteger previousIndex = [self.delegate bassIndexAtOffset:-1 fromIndex:self.currentPlaylistIndex player:self];
        ISMSSong *previousSong = [self.delegate bassSongForIndex:previousIndex player:self];
		return previousSong.duration.doubleValue + seconds;*/
        
        
        return self.previousSongForProgress.duration + seconds;
    }
    
    //ALog(@"bytepos: %lld, secs: %f", pcmBytePosition, seconds);
	
	return seconds + self.startSecondsOffset;
}

- (BassStream *)currentStream {
    @synchronized(self.streamQueue) {
        return [self.streamQueue firstObject];
    }
}

- (NSInteger)kiloBitrate {
	return [Bass estimateKiloBitrateWithBassStream:self.currentStream];
}

#pragma mark - Playback methods

- (void)stop {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
    if ([self.delegate respondsToSelector:@selector(bassStopped:)]) {
        [self.delegate bassStopped:self];
    }
	
    if (self.isPlaying) {
		BASS_Pause();
		self.isPlaying = NO;
        [NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackEnded object:nil userInfo:nil];
	}
    
    [self cleanup];
}

- (void)pause {
    if (self.isPlaying) {
		[self playPause];
    }
}

- (void)playPause {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	if (self.isPlaying) {
		BASS_Pause();
		self.isPlaying = NO;
		[NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackPaused object:nil userInfo:nil];
	} else {
		if (self.currentStream == 0) {
            // See if we're at the end of the playlist
            ISMSSong *currentSong = [self.delegate bassSongForIndex:self.currentPlaylistIndex player:self];
            if (currentSong) {
                // ALog(@"startByteOffset: %d, startSecondsOffset: %d", audioEngineS.startByteOffset, audioEngineS.startSecondsOffset);
                [self.delegate bassRetrySongAtOffsetInBytes:self.startByteOffset andSeconds:self.startSecondsOffset player:self];
            } else {
                self.currentPlaylistIndex = [self.delegate bassIndexAtOffset:-1 fromIndex:self.currentPlaylistIndex player:self];
                currentSong = [self.delegate bassSongForIndex:self.currentPlaylistIndex player:self];
                [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
            }
		} else {
			BASS_Start();
			self.isPlaying = YES;
			[NSNotificationCenter postOnMainThreadWithName:Notifications.songPlaybackStarted object:nil userInfo:nil];
		}
	}
    
    if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)]) {
        [self.delegate bassUpdateLockScreenInfo:self];
    }
}

- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	BassStream *userInfo = self.currentStream;
	if (!userInfo) return;
    
    if ([self.delegate respondsToSelector:@selector(bassSeekToPositionStarted:)]) {
        [self.delegate bassSeekToPositionStarted:self];
    }
    
    userInfo.isEnded = NO;
    //[self cleanup];
    //[self startSong:self.currentStream.song atIndex:self.currentPlaylistIndex withOffsetInBytes:@(bytes) orSeconds:nil];
	
	if (userInfo.isEnded) {
		userInfo.isEnded = NO;
		[self cleanup];
        if (self.currentStream.song) {
            ISMSSong * _Nonnull song = self.currentStream.song;
            [self startSong:song atIndex:self.currentPlaylistIndex withOffsetInBytes:@(bytes) orSeconds:nil];
        }
	} else {
		if (BASS_Mixer_ChannelSetPosition(userInfo.stream, bytes, BASS_POS_BYTE)) {
			self.startByteOffset = bytes;
			
			userInfo.neededSize = ULLONG_MAX;
			if (userInfo.isWaiting) {
				userInfo.shouldBreakWaitLoop = YES;
			}
			
			[self.ringBuffer reset];
            
            if (fadeVolume) {
                BASS_ChannelSlideAttribute(self.outStream, BASS_ATTRIB_VOL, 0, Bass.bassOutputBufferLengthMillis);
            }
            
            self.ringBuffer.totalBytesDrained = bytes / self.currentStream.channelCount / (self.currentStream.sampleRate / (double)ISMS_defaultSampleRate);
            
            if ([self.delegate respondsToSelector:@selector(bassSeekToPositionSuccess:)]) {
                [self.delegate bassSeekToPositionSuccess:self];
            }
		} else {
			[Bass logCurrentError];
		}
	}
}

- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume {
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	QWORD bytes = BASS_ChannelSeconds2Bytes(self.currentStream.stream, seconds);
	[self seekToPositionInBytes:bytes fadeVolume:fadeVolume];
}

@end
