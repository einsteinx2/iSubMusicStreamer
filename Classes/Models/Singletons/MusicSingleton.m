//
//  musicSSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MusicSingleton.h"
#import "ISMSStreamHandler.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlayQueueSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "SUSCoverArtDAO.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <MediaPlayer/MediaPlayer.h>

LOG_LEVEL_ISUB_DEFAULT

@implementation MusicSingleton

#pragma mark Control Methods

unsigned long long startSongBytes = 0;
double startSongSeconds = 0.0;
- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds {
	// Only allowed to manipulate BASS from the main thread
	if (!NSThread.mainThread) return;

    //DLog(@"starting song at offset");
	
	// Destroy the streamer to start a new song
	[audioEngineS.player stop];
	
	ISMSSong *currentSong = playlistS.currentSong;
	
    if (!currentSong) return;
	
	startSongBytes = bytes;
	startSongSeconds = seconds;
		
	// Only start the caching process if it's been a half second after the last request
	// Prevents crash when skipping through playlist fast
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(startSongAtOffsetInSeconds2) withObject:nil afterDelay:1.0];
}

// TODO: put this method somewhere and name it properly
- (void)startSongAtOffsetInSeconds2 {
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_RemoveMoviePlayer];
	
	ISMSSong *currentSong = playlistS.currentSong;
    NSUInteger currentIndex = playlistS.currentIndex;
	
	if (!currentSong) return;
    
    // Fix for bug that caused songs to sometimes start playing then immediately restart
    if (audioEngineS.player.isPlaying && [audioEngineS.player.currentStream.song isEqual:currentSong]) {
        // We're already playing this song so bail
        return;
    }
	
	// Check to see if the song is already cached
	if (currentSong.isFullyCached) {
		// The song is fully cached, start streaming from the local copy
        [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:@(startSongBytes) orSeconds:@(startSongSeconds)];
		
		// Fill the stream queue
        if (!settingsS.isOfflineMode) {
            [streamManagerS fillStreamQueue:YES];
			//[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
        }
	} else if (!currentSong.isFullyCached && settingsS.isOfflineMode) {
		[self playSongAtPosition:playlistS.nextIndex];
	} else {
		if ([cacheQueueManagerS.currentQueuedSong isEqualToSong:currentSong]) {
			// The cache queue is downloading this song, remove it before continuing
			[cacheQueueManagerS removeCurrentSong];
		}
		
		if ([streamManagerS isSongDownloading:currentSong]) {
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.player.isPlaying && handler.isDelegateNotifiedToStartPlayback) {
				// Only start the player if the handler isn't going to do it itself
                [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:@(startSongBytes) orSeconds:@(startSongSeconds)];
			}
		} else if ([streamManagerS isSongFirstInQueue:currentSong] && ![streamManagerS isQueueDownloading]) {
			// The song is first in queue, but the queue is not downloading. Probably the song was downloading
			// when the app quit. Resume the download and start the player
			[streamManagerS resumeQueue];
			
			// The song is caching, start streaming from the local copy
			ISMSStreamHandler *handler = [streamManagerS handlerForSong:currentSong];
			if (!audioEngineS.player.isPlaying && handler.isDelegateNotifiedToStartPlayback)
			{
				// Only start the player if the handler isn't going to do it itself
                [audioEngineS startSong:currentSong atIndex:currentIndex withOffsetInBytes:@(startSongBytes) orSeconds:@(startSongSeconds)];
			}
		} else {
			// Clear the stream manager
			[streamManagerS removeAllStreams];
			
			BOOL isTempCache = NO;
            if (startSongBytes > 0) {
				isTempCache = YES;
            } else if (!settingsS.isSongCachingEnabled) {
				isTempCache = YES;
            }
			
			// Start downloading the current song from the correct offset
			[streamManagerS queueStreamForSong:currentSong 
									 byteOffset:startSongBytes 
								  secondsOffset:startSongSeconds 
										atIndex:0 
									isTempCache:isTempCache
								isStartDownload:YES];
			
			// Fill the stream queue
			if (settingsS.isSongCachingEnabled)
				[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
		}
	}
}

- (void)startSong {
	[self startSongAtOffsetInBytes:0 andSeconds:0.0];
}

- (ISMSSong *)playSongAtPosition:(NSInteger)position {
	playlistS.currentIndex = position;
    ISMSSong *currentSong = playlistS.currentSong;
 
    if (!currentSong.isVideo) {
        // Remove the video player if this is not a video
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_RemoveMoviePlayer];
    }
    
	if (settingsS.isJukeboxEnabled) {
        if (currentSong.isVideo) {
            currentSong = nil;
            [SlidingNotification showOnMainWindowWithMessage:@"Cannot play videos in Jukebox mode."];
        } else {
            [jukeboxS playSongAtPosition:@(position)];
        }
	} else {
		[streamManagerS removeAllStreamsExceptForSong:playlistS.currentSong];
        
        if (currentSong.isVideo) {
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_PlayVideo userInfo:@{@"song":currentSong}];
        } else {
            [self startSong];
        }
	}
    
    return currentSong;
}

- (void)prevSong {
    DDLogInfo(@"[MusicSingleton] prevSong called");
	if (audioEngineS.player.progress > 10.0) {
		// Past 10 seconds in the song, so restart playback instead of changing songs
        DDLogInfo(@"[MusicSingleton] prevSong Past 10 seconds in the song, so restart playback instead of changing songs, calling playSongAtPosition:%lu", (unsigned long)playlistS.currentIndex);
		[self playSongAtPosition:playlistS.currentIndex];
	} else {
		// Within first 10 seconds, go to previous song
        DDLogInfo(@"[MusicSingleton] prevSong within first 10 seconds, so go to previous, calling playSongAtPosition:%lu", (unsigned long)playlistS.prevIndex);
		[self playSongAtPosition:playlistS.prevIndex];
	}
}

- (void)nextSong {
    DDLogInfo(@"[MusicSingleton] nextSong called, calling playSongAtPosition:%lu", (unsigned long)playlistS.nextIndex);
	[self playSongAtPosition:playlistS.nextIndex];
}

// Resume song after iSub shuts down
- (void)resumeSong {
	ISMSSong *currentSong = playlistS.currentSong;
		
    //DLog(@"isRecover: %@  currentSong: %@", NSStringFromBOOL(settingsS.isRecover), currentSong);
    //DLog(@"byteOffset: %llu   seekTime: %f\n   ", settingsS.byteOffset, settingsS.seekTime);
	
	if (currentSong && settingsS.isRecover) {
		[self startSongAtOffsetInBytes:settingsS.byteOffset andSeconds:settingsS.seekTime];
	} else {
		audioEngineS.startByteOffset = (NSUInteger)settingsS.byteOffset;
		audioEngineS.startSecondsOffset = settingsS.seekTime;
	}
}

#pragma mark Helper Methods

- (BOOL)showPlayerIcon {
    return !UIDevice.isPad;
}

- (void)showPlayer {
	// Start the player		
	[self playSongAtPosition:0];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
}

- (void)updateLockScreenInfo {
    NSMutableDictionary *trackInfo = [NSMutableDictionary dictionaryWithCapacity:10];
    
    ISMSSong *currentSong = playlistS.currentSong;
    if (currentSong.title)
        [trackInfo setObject:currentSong.title forKey:MPMediaItemPropertyTitle];
    if (currentSong.album)
        [trackInfo setObject:currentSong.album forKey:MPMediaItemPropertyAlbumTitle];
    if (currentSong.artist)
        [trackInfo setObject:currentSong.artist forKey:MPMediaItemPropertyArtist];
    if (currentSong.genre)
        [trackInfo setObject:currentSong.genre forKey:MPMediaItemPropertyGenre];
    if (currentSong.duration)
        [trackInfo setObject:currentSong.duration forKey:MPMediaItemPropertyPlaybackDuration];
    NSNumber *trackIndex = @(playlistS.currentIndex);
    if (trackIndex)
        [trackInfo setObject:trackIndex forKey:MPNowPlayingInfoPropertyPlaybackQueueIndex];
    NSNumber *playlistCount = @(playlistS.count);
    if (playlistCount)
        [trackInfo setObject:playlistCount forKey:MPNowPlayingInfoPropertyPlaybackQueueCount];
    NSNumber *progress = @(audioEngineS.player.progress);
    if (progress)
        [trackInfo setObject:progress forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [trackInfo setObject:@(1.0) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    
    if (settingsS.isLockScreenArtEnabled) {
        SUSCoverArtDAO *artDataModel = [[SUSCoverArtDAO alloc] initWithDelegate:nil coverArtId:currentSong.coverArtId isLarge:YES];
        UIImage *image = artDataModel.coverArtImage;
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size requestHandler:^UIImage * _Nonnull(CGSize size) {
            return artDataModel.coverArtImage;
        }];
        [trackInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }
    
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = trackInfo;
	
	// Run this every 30 seconds to update the progress and keep it in sync
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLockScreenInfo) object:nil];
	[self performSelector:@selector(updateLockScreenInfo) withObject:nil afterDelay:30.0];
}

#pragma mark Singleton methods

- (void)setup  {
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLockScreenInfo) name:ISMSNotification_AlbumArtLargeDownloaded];
}

+ (instancetype)sharedInstance {
    static MusicSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
