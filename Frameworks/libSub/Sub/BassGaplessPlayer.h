//
//  BassGaplessPlayer.h
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassWrapper.h"
#import "BassStream.h"
#import "BassEqualizer.h"
#import "BassVisualizer.h"
#import "BassGaplessPlayerDelegate.h"

@class EX2RingBuffer, SUSRegisterActionLoader;
@interface BassGaplessPlayer : NSObject

@property (weak) id<BassGaplessPlayerDelegate> delegate;

@property (strong) dispatch_queue_t streamGcdQueue;

// Ring Buffer
@property (strong) EX2RingBuffer *ringBuffer;
@property (strong) NSThread *ringBufferFillThread;

// BASS streams
@property (strong) NSMutableArray *streamQueue;
@property (readonly) BassStream *currentStream;
@property (copy) ISMSSong *previousSongForProgress;
@property (nonatomic) HSTREAM outStream;
@property (nonatomic) HSTREAM mixerStream;

@property BOOL isPlaying;
@property (readonly) BOOL isStarted;
@property (readonly) NSInteger bitRate;
@property (readonly) QWORD currentByteOffset;
@property (readonly) double progress;
@property (strong) BassStream *waitLoopStream;

@property NSUInteger startByteOffset;
@property NSUInteger startSecondsOffset;

@property (strong) BassEqualizer *equalizer;
@property (strong) BassVisualizer *visualizer;

@property NSUInteger currentPlaylistIndex;
        
- (id)initWithDelegate:(id<BassGaplessPlayerDelegate>)theDelegate;

// BASS methods
//
- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length;
- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds;
//- (void)prepareNextSongStream;

+ (NSUInteger)bytesToBufferForKiloBitrate:(NSUInteger)rate speedInBytesPerSec:(NSUInteger)speedInBytesPerSec;

// Playback methods
//
//- (void)start;
- (void)stop;
- (void)pause;
- (void)playPause;
- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume;
- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume;

- (BOOL)testStreamForSong:(ISMSSong *)aSong;
- (BassStream *)prepareStreamForSong:(ISMSSong *)aSong;

@end
