//
//  SUSNowPlayingDAO.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingDAO.h"
#import "SUSNowPlayingLoader.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation SUSNowPlayingDAO

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		_delegate = theDelegate;
		_nowPlayingSongDicts = nil;
    }
    
    return self;
}

- (void)dealloc
{
	[_loader cancelLoad];
	_loader.delegate = nil;
    _loader = nil;
}

#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	if (self.nowPlayingSongDicts)
		return [self.nowPlayingSongDicts count];
	
	return 0;
}

- (ISMSSong *)songForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [self.nowPlayingSongDicts objectAtIndexSafe:index];
		ISMSSong *aSong = [songDict objectForKey:@"song"];
		return aSong;
	}
	return nil;
}

- (NSString *)playTimeForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [self.nowPlayingSongDicts objectAtIndexSafe:index];
		NSUInteger minutesAgo = [[songDict objectForKey:@"minutesAgo"] intValue];
		
		if (minutesAgo == 1)
			return [NSString stringWithFormat:@"%lu min ago", (unsigned long)minutesAgo];
		else
			return [NSString stringWithFormat:@"%lu mins ago", (unsigned long)minutesAgo];
	}
	return nil;
}

- (NSString *)usernameForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [self.nowPlayingSongDicts objectAtIndexSafe:index];
		return [songDict objectForKey:@"username"];
	}
	return nil;
}

- (NSString *)playerNameForIndex:(NSUInteger)index
{
	if (index < self.count)
	{
		NSDictionary *songDict = [self.nowPlayingSongDicts objectAtIndexSafe:index];
		return [songDict objectForKey:@"playerName"];
	}
	return nil;
}

- (ISMSSong *)playSongAtIndex:(NSUInteger)index
{
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Add the song to the empty playlist
	ISMSSong *aSong = [self songForIndex:index];
	[aSong addToCurrentPlaylistDbQueue];
	
	// Set player defaults
	playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Start the song
	return [musicS playSongAtPosition:0];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[SUSNowPlayingLoader alloc] initWithDelegate:self];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	self.nowPlayingSongDicts = [NSArray arrayWithArray:self.loader.nowPlayingSongDicts];
	
	self.loader.delegate = nil;
	self.loader = nil;
		
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
