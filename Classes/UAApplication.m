//
//  UAApplication.m
//  iSub
//
//  Created by Ben Baron on 6/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UAApplication.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation UAApplication

- (id)init 
{
	if ((self = [super init]))
	{
		[self becomeFirstResponder];
		
		if ([self respondsToSelector:@selector(beginReceivingRemoteControlEvents)])
			[self beginReceivingRemoteControlEvents];
	}
	return self;
}

#pragma mark - UIResponder

-(BOOL)canBecomeFirstResponder 
{
    return YES;
}

#pragma mark - Motion

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{
	
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{
	if (motion == UIEventSubtypeMotionShake) 
	{
        //DLog(@"oh ya, shake it now!");
	}
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event 
{ 
	
}

#pragma mark - Remote Control

- (void)playPauseStop
{
	DDLogVerbose(@"[UAApplication] playPauseStop called");
	if (settingsS.isJukeboxEnabled)
	{
		DDLogVerbose(@"[UAApplication] playPauseStop jukebox is enabled");
		if (jukeboxS.jukeboxIsPlaying)
		{
			DDLogVerbose(@"[UAApplication] jukebox is playing, playPauseStop jukeboxStop called");
			[jukeboxS jukeboxStop];
		}
		else
		{
			DDLogVerbose(@"[UAApplication] jukebox NOT playing, playPauseStop jukeboxPlay called");
			[jukeboxS jukeboxPlay];
		}
	}
	else
	{
		DDLogVerbose(@"[UAApplication] playPauseStop jukebox NOT enabled");
        if (audioEngineS.player)
		{
			DDLogVerbose(@"[UAApplication] audio engine player exists, playPauseStop [audioEngineS.player playPause] called");
			[audioEngineS.player playPause];
		}
		else
		{
			DDLogVerbose(@"[UAApplication] audio engine player doesn't exist, playPauseStop [musicS playSongAtPosition:playlistS.currentIndex] called");
			[musicS playSongAtPosition:playlistS.currentIndex];
		}
	}
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event 
{
	DDLogVerbose(@"[UAApplication] remoteControlReceivedWithEvent type: %li  subtype: %li  timestamp: %f", (long)event.type, (long)event.subtype, event.timestamp);
	switch(event.subtype) 
	{
		case UIEventSubtypeRemoteControlPlay:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPlay, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlPause:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlStop:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlStop, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlTogglePlayPause, calling playPauseStop");
			[self playPauseStop];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			DDLogVerbose(@"UIEventSubtypeRemoteControlNextTrack, calling nextSong");
			[musicS nextSong];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			DDLogVerbose(@"[UAApplication] UIEventSubtypeRemoteControlPreviousTrack, calling prevSong");
			[musicS prevSong];
			break;
		default:
			return;
	}	
}

@end
