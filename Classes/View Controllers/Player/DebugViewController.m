//
//  DebugViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DebugViewController.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "CacheSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation DebugViewController

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.currentSongProgress = 0.;
	self.nextSongProgress = 0.;
		
    // Cache the song objects
    [self cacheSongObjects];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects)
                                                 name:ISMSNotification_SongPlaybackStarted object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects)
                                                 name:ISMSNotification_SongPlaybackEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheSongObjects)
                                                 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
    
    // Set the fields
    [self updateStats];
}

- (void)showStore
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"player show store"];
}


- (void)viewDidDisappear:(BOOL)animated
{	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	 self.currentSongProgressView = nil;
	 self.nextSongLabel = nil;
	 self.nextSongProgressView = nil;
	
	 self.songsCachedLabel = nil;
	 self.cacheSizeLabel = nil;
	 self.cacheSettingLabel = nil;
	 self.cacheSettingSizeLabel = nil;
	 self.freeSpaceLabel = nil;
	
	 self.songInfoToggleButton = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
}

#pragma mark -

- (void)cacheSongObjects
{
	self.currentSong = playlistS.currentDisplaySong;
	self.nextSong = playlistS.nextSong;
}
		 
- (void)updateStats
{
	if (!settingsS.isJukeboxEnabled)
	{
		// Set the current song progress bar
		if (![self.currentSong isTempCached])
			self.currentSongProgress = self.currentSong.downloadProgress;
		
		self.nextSongProgress = self.nextSong.downloadProgress;
	}
	
	if (settingsS.isJukeboxEnabled)
	{
		self.currentSongProgressView.progress = 0.0;
		self.currentSongProgressView.alpha = 0.2;
		
		self.nextSongProgressView.progress = 0.0;
		self.nextSongProgressView.alpha = 0.2;
	}
	else
	{
		// Set the current song progress bar
		if ([self.currentSong isTempCached])
		{
			self.currentSongProgressView.progress = 0.0;
			self.currentSongProgressView.alpha = 0.2;
		}
		else
		{
			self.currentSongProgressView.progress = self.currentSongProgress;
			self.currentSongProgressView.alpha = 1.0;
		}
				
		// Set the next song progress bar
		if (self.nextSong.path != nil)
		{
			// Make sure label and progress view aren't greyed out
			self.nextSongLabel.alpha = 1.0;
			self.nextSongProgressView.alpha = 1.0;
		}
		else
		{
			// There is no next song, so return 0 and grey out the label and progress view
			self.nextSongLabel.alpha = 0.2;
			self.nextSongProgressView.alpha = 0.2;
		}
		self.nextSongProgressView.progress = self.nextSongProgress;
	}
	
	// Set the number of songs cached label
	NSUInteger cachedSongs = cacheS.numberOfCachedSongs;
	if (cachedSongs == 1)
		self.songsCachedLabel.text = @"1 song";
	else
		self.songsCachedLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)cachedSongs];
	
	// Set the cache setting labels
	if (settingsS.cachingType == ISMSCachingType_minSpace)
	{
		self.cacheSettingLabel.text = @"Min Free Space:";
		self.cacheSettingSizeLabel.text = [NSString formatFileSize:settingsS.minFreeSpace];
	}
	else
	{
		self.cacheSettingLabel.text = @"Max Cache Size:";
		self.cacheSettingSizeLabel.text = [NSString formatFileSize:settingsS.maxCacheSize];
	}
	
	// Set the free space label
	self.freeSpaceLabel.text = [NSString formatFileSize:cacheS.freeSpace];
	
	// Set the cache size label
	self.cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
	
	[self performSelector:@selector(updateStats) withObject:nil afterDelay:1.0];
}

- (IBAction)songInfoToggle
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"hideSongInfo"];
}

@end
