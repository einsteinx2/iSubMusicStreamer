//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialSingleton.h"
#import "BassGaplessPlayer.h"
#import "ISMSStreamManager.h"
#import "NSMutableURLRequest+SUS.h"
#import "SUSScrobbleLoader.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "ISMSStreamManager.h"
#import "Defines.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation SocialSingleton

#pragma mark Class instance methods

- (void)playerClearSocial {
	self.playerHasScrobbled = NO;
    self.playerHasSubmittedNowPlaying = NO;
    self.playerHasNotifiedSubsonic = NO;
}

- (void)playerHandleSocial {
    if (!self.playerHasNotifiedSubsonic && audioEngineS.player.progress >= socialS.subsonicDelay) {
        if (settingsS.currentServer.type == ServerTypeSubsonic) {
            [EX2Dispatch runInMainThreadAsync:^{
                [self notifySubsonic];
            }];
        }
        self.playerHasNotifiedSubsonic = YES;
    }
    
	if (!self.playerHasScrobbled && audioEngineS.player.progress >= socialS.scrobbleDelay) {
		self.playerHasScrobbled = YES;
		[EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsSubmission];
		}];
	}
    
    if (!self.playerHasSubmittedNowPlaying) {
        self.playerHasSubmittedNowPlaying = YES;
        [EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsPlaying];
		}];
    }
}

- (NSTimeInterval)scrobbleDelay {
	// Scrobble in 30 seconds (or settings amount) if not canceled
	ISMSSong *currentSong = audioEngineS.player.currentStream.song;
	NSTimeInterval scrobbleDelay = 30.0;
	if (currentSong.duration != 0) {
		float scrobblePercent = settingsS.scrobblePercent;
		float duration = currentSong.duration;
		scrobbleDelay = scrobblePercent * duration;
	}
	return scrobbleDelay;
}

- (NSTimeInterval)subsonicDelay {
	return 10.0;
}

- (void)notifySubsonic {
    // TODO: This no longer works on new Subsonic versions, need to look for an alternate solution
//	if (!settingsS.isOfflineMode) {
//		// If this song wasn't just cached, then notify Subsonic of the playback
//		ISMSSong *lastCachedSong = streamManagerS.lastCachedSong;
//		ISMSSong *currentSong = PlayQueue.shared.currentSong;
//		if (![lastCachedSong isEqual:currentSong]) {
//            NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:@{@"id": n2N(currentSong.songId)} byteOffset:0];
//            if ([[NSURLConnection alloc] initWithRequest:request delegate:self])
//            {
//                DDLogInfo(@"[SocialSingleton] notified Subsonic about cached song %@", currentSong.title);
//            }
//		}
//	}
}

#pragma mark Scrobbling

- (void)scrobbleSongAsSubmission {
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode) {
		ISMSSong *currentSong = PlayQueue.shared.currentSong;
		[self scrobbleSong:currentSong isSubmission:YES];
	}
}

- (void)scrobbleSongAsPlaying {
	// If scrobbling is enabled, send "now playing" call
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode) {
		ISMSSong *currentSong = PlayQueue.shared.currentSong;
		[self scrobbleSong:currentSong isSubmission:NO];
	}
}

- (void)scrobbleSong:(ISMSSong*)aSong isSubmission:(BOOL)isSubmission {
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode) {
		SUSScrobbleLoader *loader = [[SUSScrobbleLoader alloc] initWithCallback:^(BOOL success, NSError *error) {
            DDLogInfo(@"[SocialSingleton] Scrobble successfully completed for song: %@", aSong.title);
        }];
        loader.aSong = aSong;
        loader.isSubmission = isSubmission;
        [loader startLoad];
	}
}

#pragma mark Singleton methods

+ (instancetype)sharedInstance {
    static SocialSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
