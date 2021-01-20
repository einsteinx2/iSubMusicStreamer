//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

//#import "AudioEngine.h"
//#import "BassParamEqValue.h"
//#import "BassEffectDAO.h"
//#import "BassStream.h"
//#import "ISMSStreamManager.h"
//#import "Defines.h"
//#import "EX2Kit.h"
//#import "Swift.h"
//#import <AudioToolbox/AudioToolbox.h>
//#import <AVFoundation/AVFoundation.h>
//#import <sys/stat.h>

//@implementation AudioEngine
//
//- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds {
//	// Stop the player
//	[self.player stop];
//
//    // Start the new song
//    [self.player startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds];
//
//    // Load the EQ
//    BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
//    [effectDAO selectPresetId:effectDAO.selectedPresetId];
//}
//
//- (void)startEmptyPlayer {
//    // Stop the player if it exists
//	[self.player stop];
//
//    // Create a new player if needed
//    if (!self.player)
//    {
//        self.player = [[BassGaplessPlayer alloc] initWithDelegate:self.delegate];
//    }
//}
//
//- (BassEqualizer *)equalizer {
//	return self.player.equalizer;
//}
//
//- (BassVisualizer *)visualizer {
//	return self.player.visualizer;
//}
//
//- (void)setup {
//    _delegate = [[iSubBassGaplessPlayerDelegate alloc] init];
//
//    // Run async to prevent potential deadlock from dispatch_once
//    [EX2Dispatch runInMainThreadAsync:^{
//        [self startEmptyPlayer];
//    }];
//}
//
//+ (instancetype)sharedInstance {
//    static AudioEngine *sharedInstance = nil;
//    static dispatch_once_t once = 0;
//    dispatch_once(&once, ^{
//		sharedInstance = [[self alloc] init];
////		[sharedInstance setup];
//	});
//    return sharedInstance;
//}
//
//@end
