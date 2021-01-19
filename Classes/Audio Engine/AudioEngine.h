//
//  AudioEngine.h
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_AudioEngine_h
#define iSub_AudioEngine_h

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassWrapper.h"
#import "BassStream.h"
#import "BassEqualizer.h"
#import "BassVisualizer.h"
#import "BassGaplessPlayer.h"
#import "iSubBassGaplessPlayerDelegate.h"

#define audioEngineS ((AudioEngine *)[AudioEngine sharedInstance])

NS_ASSUME_NONNULL_BEGIN

@class ISMSSong, BassParamEqValue, BassStream, SUSRegisterActionLoader, EX2RingBuffer;
NS_SWIFT_NAME(AudioEngine)
@interface AudioEngine : NSObject

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

@property BOOL shouldResumeFromInterruption;

@property (nullable, readonly) BassEqualizer *equalizer;
@property (nullable, readonly) BassVisualizer *visualizer;
@property (nullable, strong) BassGaplessPlayer *player;

@property NSUInteger startByteOffset;
@property NSUInteger startSecondsOffset;

@property (nullable, strong) iSubBassGaplessPlayerDelegate *delegate;

- (void)setup;

// BASS methods
//
- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds;
- (void)startEmptyPlayer;

@end

NS_ASSUME_NONNULL_END

#endif
