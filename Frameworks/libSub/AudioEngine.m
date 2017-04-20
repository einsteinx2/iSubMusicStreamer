//
//  AudioEngine.m
//  iSub
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "AudioEngine.h"
#import "BassParamEqValue.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MusicSingleton.h"
#import "BassEffectDAO.h"
#import <sys/stat.h>
#import "BassStream.h"
#import "ISMSStreamManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioEngine

LOG_LEVEL_ISUB_DEFAULT

// Singleton object
static AudioEngine *sharedInstance = nil;

#ifdef IOS

- (void)beginInterruption
{
    DDLogCVerbose(@"[AudioEngine] audio session begin interruption");
    if (self.player.isPlaying)
    {
        self.shouldResumeFromInterruption = YES;
        [sharedInstance.player pause];
    }
    else
    {
        self.shouldResumeFromInterruption = NO;
    }
}

- (void)endInterruptionWithFlags:(NSUInteger)flags
{
    DDLogCVerbose(@"[AudioEngine] audio session interruption ended, isPlaying: %@   isMainThread: %@", NSStringFromBOOL(sharedInstance.player.isPlaying), NSStringFromBOOL([NSThread isMainThread]));
    if (self.shouldResumeFromInterruption && flags == AVAudioSessionInterruptionFlags_ShouldResume)
    {
        [self.player playPause];
    }
    
    // Reset the shouldResumeFromInterruption value
    self.shouldResumeFromInterruption = NO;
}

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) 
{			
	DDLogCInfo(@"[AudioEngine] audioRouteChangeListenerCallback called, propertyId: %lu  isMainThread: %@", (unsigned long)inPropertyID, NSStringFromBOOL([NSThread isMainThread]));
	
    // ensure that this callback was invoked for a route change
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) 
		return;
	
	if (sharedInstance.player.isPlaying)
	{
		// Determines the reason for the route change, to ensure that it is not
		// because of a category change.
		CFDictionaryRef routeChangeDictionary = inPropertyValue;
		CFNumberRef routeChangeReasonRef = CFDictionaryGetValue (routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 routeChangeReason;
		CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
		
		DDLogCInfo(@"[AudioEngine] route change reason: %li", (long)routeChangeReason);
		
        // "Old device unavailable" indicates that a headset was unplugged, or that the
        // device was removed from a dock connector that supports audio output. This is
        // the recommended test for when to pause audio.
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) 
		{
			[sharedInstance.player playPause];
			
            DDLogCInfo(@"[AudioEngine] Output device removed, so application audio was paused.");
        }
		else 
		{
            DDLogCInfo(@"[AudioEngine] A route change occurred that does not require pausing of application audio.");
        }
    }
	else 
	{	
        DDLogCInfo(@"[AudioEngine] Audio route change while application audio is stopped.");
        return;
    }
}

#endif

- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{
	// Stop the player
	[self.player stop];
    
    // Start the new song
    [self.player startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds];
    
    // Load the EQ
    BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    [effectDAO selectPresetId:effectDAO.selectedPresetId];
}

- (void)startEmptyPlayer
{    
    // Stop the player if it exists
	[self.player stop];
    
    // Create a new player if needed
    if (!self.player)
    {
        self.player = [[BassGaplessPlayer alloc] initWithDelegate:self.delegate];
    }
}

- (BassEqualizer *)equalizer
{
	return self.player.equalizer;
}

- (BassVisualizer *)visualizer
{
	return self.player.visualizer;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DDLogError(@"[AudioEngine] received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	
	AudioSessionInitialize(NULL, NULL, NULL, NULL);
    
    [[AVAudioSession sharedInstance] setDelegate:self];
	
	// Add the callbacks for headphone removal and other audio takeover
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, NULL);
#endif
    
    _delegate = [[iSubBassGaplessPlayerDelegate alloc] init];
    
    // Run async to prevent potential deadlock from dispatch_once
    [EX2Dispatch runInMainThreadAsync:^{
        [self startEmptyPlayer];
    }];
}

+ (id)sharedInstance
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
