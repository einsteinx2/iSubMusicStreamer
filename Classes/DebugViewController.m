//
//  DebugViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DebugViewController.h"

@implementation DebugViewController

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.currentSongProgress = 0.;
	self.nextSongProgress = 0.;
		
	if (settingsS.isCacheUnlocked)
	{
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
	else
	{
		// Display the unlock cache feature screen
		
		for (UIView *subView in self.view.subviews)
		{
			subView.hidden = YES;
		}
		self.songInfoToggleButton.enabled = NO;
		
		UIImageView *noCacheScreen = [[UIImageView alloc] init];
		noCacheScreen.userInteractionEnabled = YES;
		noCacheScreen.frame = CGRectMake(40, 80, 240, 180);
		noCacheScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		textLabel.text = @"Caching\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
		[noCacheScreen addSubview:textLabel];
		
		UILabel *textLabel2 = [[UILabel alloc] init];
		textLabel2.backgroundColor = [UIColor clearColor];
		textLabel2.textColor = [UIColor whiteColor];
		textLabel2.font = ISMSBoldFont(14);
		textLabel2.textAlignment = NSTextAlignmentCenter;
		textLabel2.numberOfLines = 0;
		textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
		textLabel2.frame = CGRectMake(20, 90, 200, 70);
		[noCacheScreen addSubview:textLabel2];
		
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noCacheScreen.frame.size.width, noCacheScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noCacheScreen addSubview:storeLauncher];
		
		[self.view addSubview:noCacheScreen];
		
	}
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
