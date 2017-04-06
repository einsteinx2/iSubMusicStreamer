//
//  CacheViewController.m
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheViewController.h"
#import "CacheAlbumViewController.h"
#import "CacheQueueSongUITableViewCell.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "CacheArtistUITableViewCell.h"
#import "StoreViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface CacheViewController ()
- (void)addNoSongsScreen;
- (void)segmentAction:(id)sender;
- (void)removeSaveEditButtons;
- (void)addSaveEditButtons;
- (void)removeNoSongsScreen;
@property NSUInteger cacheQueueCount;
@end

@implementation CacheViewController

@synthesize listOfArtists, listOfArtistsSections, sectionInfo, cacheQueueCount, cacheSizeLabel;
@synthesize headerView, headerView2, segmentedControl, songsCountLabel, deleteSongsLabel, deleteSongsButton, editSongsLabel, editSongsButton, isSaveEditShowing;
@synthesize playAllImage, playAllLabel, playAllButton, shuffleImage, shuffleLabel, shuffleButton;
@synthesize isNoSongsScreenShowing, noSongsScreen, jukeboxInputBlocker, showIndex;

#pragma mark - Rotation handling

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD() && isNoSongsScreenShowing)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:duration];
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			noSongsScreen.transform = CGAffineTransformTranslate(noSongsScreen.transform, 0.0, -23.0);
		}
		else
		{
			noSongsScreen.transform = CGAffineTransformTranslate(noSongsScreen.transform, 0.0, 110.0);
		}
		[UIView commitAnimations];
	}
}

#pragma mark - View lifecycle

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerForNotifications
{
	// Set notification receiver for when queued songs finish downloading to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:ISMSNotification_StreamHandlerSongDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:ISMSNotification_CacheQueueSongDownloaded object:nil];
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"cachedSongDeleted" object:nil];
	
	// Set notification receiver for when network status changes to reload the table
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(segmentAction:) name:EX2ReachabilityNotification_ReachabilityChanged object: nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StreamHandlerSongDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CacheQueueSongDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cachedSongDeleted" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:EX2ReachabilityNotification_ReachabilityChanged object:nil];
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	
	//DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	//DLog(@"Cache viewDidLoad");
	
	self.cacheSizeLabel = nil;
	
	self.jukeboxInputBlocker = nil;
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
	self.isNoSongsScreenShowing = NO;
	self.isSaveEditShowing = NO;
		
	self.tableView.separatorColor = [UIColor clearColor];
	
	if (settingsS.isOfflineMode)
	{
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] 
																				  style:UIBarButtonItemStyleBordered 
																				 target:self 
																				 action:@selector(settingsAction:)];
	}
	
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Cached", @"Downloading"]];
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	
	self.segmentedControl.frame = CGRectMake(5, 5, 310, 36);
	self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (IS_IOS7())
        self.segmentedControl.tintColor = ISMSHeaderColor;
	else
        self.segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	self.segmentedControl.selectedSegmentIndex = 0;
	if (settingsS.isOfflineMode) 
	{
		self.segmentedControl.hidden = YES;
	}
	[self.headerView addSubview:self.segmentedControl];
	
	if (settingsS.isOfflineMode) 
	{
		self.headerView.frame = CGRectMake(0, 0, 320, 50);
		self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		self.headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		self.headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.headerView2.backgroundColor = viewObjectsS.darkNormal;
		[self.headerView addSubview:self.headerView2];
		
		self.playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
		self.playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
		self.playAllLabel.backgroundColor = [UIColor clearColor];
		self.playAllLabel.textColor = ISMSHeaderButtonColor;
		self.playAllLabel.textAlignment = NSTextAlignmentCenter;
		self.playAllLabel.font = ISMSRegularFont(24);
		self.playAllLabel.text = @"Play All";
		[self.headerView2 addSubview:self.playAllLabel];
		
		self.playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
		self.playAllButton.frame = CGRectMake(0, 0, 160, 40);
		[self.playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView2 addSubview:self.playAllButton];
		
		self.shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
		self.shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
		self.shuffleLabel.backgroundColor = [UIColor clearColor];
		self.shuffleLabel.textColor = ISMSHeaderButtonColor;
		self.shuffleLabel.textAlignment = NSTextAlignmentCenter;
		self.shuffleLabel.font = ISMSRegularFont(24);
		self.shuffleLabel.text = @"Shuffle";
		[self.headerView2 addSubview:self.shuffleLabel];
		
		self.shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
		self.shuffleButton.frame = CGRectMake(160, 0, 160, 40);
		[self.shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView2 addSubview:self.shuffleButton];
	}
	
	self.tableView.tableHeaderView = self.headerView;
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	
	if (settingsS.isOfflineMode)
	{
		self.title = @"Artists";
	}
	else 
	{
		self.title = @"Cache";
		
		// Setup the update timer
		[self updateQueueDownloadProgress];
		
		//[self registerForNotifications];
	}
	
	if (IS_IPAD())
		self.view.backgroundColor = ISMSiPadBackgroundColor;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
	
	//DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	[self registerForNotifications];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewWillAppear:) name:ISMSNotification_StorePurchaseComplete object:nil];
	
	[self reloadTable];
	
	[self updateQueueDownloadProgress];
	[self updateCacheSizeLabel];
	
	[Flurry logEvent:@"CacheTab"];
	
	// Reload the data in case it changed
	if (settingsS.isCacheUnlocked)
	{
		self.tableView.tableHeaderView.hidden = NO;
		
		//segmentedControl.selectedSegmentIndex = 0;
		[self segmentAction:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self addNoSongsScreen];
	}
	
	self.tableView.scrollEnabled = YES;
	[self.jukeboxInputBlocker removeFromSuperview];
	self.jukeboxInputBlocker = nil;
	if (settingsS.isJukeboxEnabled)
	{
		self.tableView.scrollEnabled = NO;
		
		self.jukeboxInputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		self.jukeboxInputBlocker.frame = CGRectMake(0, 0, 1004, 1004);
		[self.view addSubview:self.jukeboxInputBlocker];
		
		UIView *colorView = [[UIView alloc] initWithFrame:self.jukeboxInputBlocker.frame];
		colorView.backgroundColor = [UIColor blackColor];
		colorView.alpha = 0.5;
		[self.jukeboxInputBlocker addSubview:colorView];
	}
    
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
    if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}    
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	// Must do this here as well or the no songs overlay will be off sometimes
	if (settingsS.isCacheUnlocked)
	{
		self.tableView.tableHeaderView.hidden = NO;
		
		//segmentedControl.selectedSegmentIndex = 0;
		[self segmentAction:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		[self addNoSongsScreen];
	}
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	//DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	[self unregisterForNotifications];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}


- (void)segmentAction:(id)sender
{
	//DLog(@"isVisible: %@", NSStringFromBOOL(self.isVisible));
	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (self.tableView.editing)
		{
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if (self.listOfArtists.count == 0)
		{
			[self removeSaveEditButtons];
			
			[self addNoSongsScreen];
			[self addNoSongsScreen];
		}
		else 
		{
			[self removeNoSongsScreen];
			
			if (settingsS.isOfflineMode == NO)
			{
				[self addSaveEditButtons];
			}
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1)
	{
		if (self.tableView.editing)
		{
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if (self.cacheQueueCount > 0)
		{
			[self removeNoSongsScreen];
			[self addSaveEditButtons];
		}
	}
	
	[self.tableView reloadData];
}

#pragma mark - Button Handling

- (void)showStore
{
	StoreViewController *store = [[StoreViewController alloc] init];
	//DLog(@"store: %@", store);
	[self pushViewControllerCustom:store];
}

- (void)settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)playAllAction:(id)sender
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"NO" afterDelay:0.05];
}

- (void)shuffleAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"YES" afterDelay:0.05];
}

- (void)loadPlayAllPlaylist:(NSString *)shuffle
{			
	playlistS.isShuffle = NO;
	
	BOOL isShuffle;
	if ([shuffle isEqualToString:@"YES"])
		isShuffle = YES;
	else
		isShuffle = NO;
	
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE"];
		while ([result next])
		{			
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	if (isShuffle)
	{
		playlistS.isShuffle = YES;
		[databaseS shufflePlaylist];
	}
	else
	{
		playlistS.isShuffle = NO;
	}
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxPlaySongAtPosition:@(0)];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Must do UI stuff in main thread
	[viewObjectsS hideLoadingScreen];
	[self playAllPlaySong];	
}

#pragma mark -

- (void)reloadTable
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		// Create the artist list
		self.listOfArtists = [NSMutableArray arrayWithCapacity:1];
		self.listOfArtistsSections = [NSMutableArray arrayWithCapacity:28];
		
		// Fix for slow load problem (EDIT: Looks like it didn't actually work :(
		[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistList"];
			[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
			[db executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
			
			FMResultSet *result = [db executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
			while ([result next])
			{
				@autoreleasepool 
				{
					// Cover up for blank insert problem
					NSString *artist = [result stringForColumnIndex:0];
					if (artist.length > 0)
						[listOfArtists addObject:[artist copy]];
				}
			}
			[result close];
			
			[self.listOfArtists sortUsingSelector:@selector(caseInsensitiveCompareWithoutIndefiniteArticles:)];
			//DLog(@"listOfArtists: %@", listOfArtists);
			
			// Create the section index
			[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistIndex"];
			[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)"];
			//DLog(@"listOfArtists: %@", self.listOfArtists);
			for (NSString *artist in self.listOfArtists)
			{
				[db executeUpdate:@"INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", [artist stringWithoutIndefiniteArticle], nil];
			}
		}];
		
		self.sectionInfo = [databaseS sectionInfoFromTable:@"cachedSongsArtistIndex" inDatabaseQueue:databaseS.songCacheDbQueue withColumn:@"artist"];
		//DLog(@"sectionInfo: %@", sectionInfo);
		self.showIndex = YES;
		if ([self.sectionInfo count] < 5)
			self.showIndex = NO;
		
		//DLog(@"sectionInfo: %@", sectionInfo);
		
		// Sort into sections		
		if ([self.sectionInfo count] > 0)
		{
			int lastIndex = 0;
			for (int i = 0; i < [self.sectionInfo count] - 1; i++)
			{
				@autoreleasepool {
					int index = [[[self.sectionInfo objectAtIndexSafe:i+1] objectAtIndexSafe:1] intValue];
					NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
					for (int i = lastIndex; i < index; i++)
					{
						[section addObject:[self.listOfArtists objectAtIndexSafe:i]];
					}
					[self.listOfArtistsSections addObject:section];
					lastIndex = index;
				}
			}
			NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
			for (int i = lastIndex; i < [self.listOfArtists count]; i++)
			{
				[section addObject:[self.listOfArtists objectAtIndexSafe:i]];
			}
			[self.listOfArtistsSections addObject:section];
		}
        
        NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
		if (cachedSongsCount == 0)
		{
			[self removeSaveEditButtons];
			[self addNoSongsScreen];
			[self addNoSongsScreen];
		}
		else
		{
			if (self.isSaveEditShowing)
			{
				if (cachedSongsCount == 1)
					self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
				else
					self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
			}
			else if (settingsS.isOfflineMode == NO)
			{
				[self addSaveEditButtons];
			}
			
			[self removeNoSongsScreen];
		}
	}
	else
	{
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXISTS cacheQueueList"];
			//[databaseS.cacheQueueDb executeUpdate:[NSString stringWithFormat:@"CREATE TEMP TABLE cacheQueueList (md5 TEXT, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE TEMP TABLE cacheQueueList (md5 TEXT)"];
			[db executeUpdate:@"INSERT INTO cacheQueueList SELECT md5 FROM cacheQueue"];
			
			if (self.tableView.editing)
			{
				NSArray *multiDeleteList = [NSArray arrayWithArray:viewObjectsS.multiDeleteList];
				for (NSString *md5 in multiDeleteList)
				{
					NSString *dbMd5 = [db stringForQuery:@"SELECT md5 FROM cacheQueueList WHERE md5 = ?", md5];
					//DLog(@"md5: %@   dbMD5: %@", md5, dbMd5);
					if (!dbMd5) 
						[viewObjectsS.multiDeleteList removeObject:md5];
				}
			}
		}];
		
		self.cacheQueueCount = [databaseS.cacheQueueDbQueue intForQuery:@"SELECT COUNT(*) FROM cacheQueueList"];
		if (self.cacheQueueCount == 0)
		{
			[self removeSaveEditButtons];	
			[self addNoSongsScreen];
			[self addNoSongsScreen];
		}
		else
		{
			if (self.isSaveEditShowing)
			{
				if (self.cacheQueueCount == 1)
					self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
				else 
					self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)self.cacheQueueCount];
			}
			else
			{
				[self addSaveEditButtons];
			}
			
			if (self.isNoSongsScreenShowing)
				[self removeNoSongsScreen];
		}
	}
	
	[self.tableView reloadData];
}

- (void)updateCacheSizeLabel
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (cacheS.cacheSize <= 0)
			self.cacheSizeLabel.text = @"";
		else
			self.cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
	
	// Call again in a couple seconds
	[self performSelector:@selector(updateCacheSizeLabel) withObject:nil afterDelay:2.0];
}

- (void)updateQueueDownloadProgress
{
	if (self.segmentedControl.selectedSegmentIndex == 1 && cacheQueueManagerS.isQueueDownloading)
	{	
		[self reloadTable];
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	
	// Call again in a second
	[self performSelector:@selector(updateQueueDownloadProgress) withObject:nil afterDelay:1.];
}

- (void)removeSaveEditButtons
{
	if (self.isSaveEditShowing == YES)
	{
		self.isSaveEditShowing = NO;
		[self.songsCountLabel removeFromSuperview]; 
		self.songsCountLabel = nil;
		[self.deleteSongsButton removeFromSuperview]; 
		self.deleteSongsButton = nil;
		[self.editSongsLabel removeFromSuperview]; 
		self.editSongsLabel = nil;
		[self.editSongsButton removeFromSuperview]; 
		self.editSongsButton = nil;
		[self.deleteSongsLabel removeFromSuperview]; 
		self.deleteSongsLabel = nil;
		[self.cacheSizeLabel removeFromSuperview]; 
		self.cacheSizeLabel = nil;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
		[headerView2 removeFromSuperview]; 
		self.headerView2 = nil;
		
		self.headerView.frame = CGRectMake(0, 0, 320, 44);
		
		self.tableView.tableHeaderView = self.headerView;
	}
}

- (void)addSaveEditButtons
{
	[self removeSaveEditButtons];
	
	if (self.isSaveEditShowing == NO)
	{
		// Modify the header view to include the save and edit buttons
		self.isSaveEditShowing = YES;
		int y = 43;
		
		self.headerView.frame = CGRectMake(0, 0, 320, y + 100);
		if (self.segmentedControl.selectedSegmentIndex == 1)
			self.headerView.frame = CGRectMake(0, 0, 320, y + 50);
		
		self.songsCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 160, 34)];
		self.songsCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.songsCountLabel.backgroundColor = [UIColor clearColor];
		self.songsCountLabel.textColor = [UIColor whiteColor];
		self.songsCountLabel.textAlignment = NSTextAlignmentCenter;
		self.songsCountLabel.font = ISMSBoldFont(22);
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
			if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"] == 1)
				self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
			else 
				self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			if (self.cacheQueueCount == 1)
				self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
			else 
				self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)self.cacheQueueCount];
		}
		[self.headerView addSubview:self.songsCountLabel];
		
		self.cacheSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 160, 14)];
		self.cacheSizeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.cacheSizeLabel.backgroundColor = [UIColor clearColor];
		self.cacheSizeLabel.textColor = [UIColor whiteColor];
		self.cacheSizeLabel.textAlignment = NSTextAlignmentCenter;
		self.cacheSizeLabel.font = ISMSBoldFont(12);
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			if (cacheS.cacheSize <= 0)
				self.cacheSizeLabel.text = @"";
			else
				self.cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			/*unsigned long long combinedSize = 0;
			FMResultSet *result = [databaseS.cacheQueueDb executeQuery:@"SELECT size FROM cacheQueue"];
			while ([result next])
			{
				combinedSize += [result longLongIntForColumnIndex:0];
			}
			[result close];
			cacheSizeLabel.text = [NSString formatFileSize:combinedSize];*/
			
			self.cacheSizeLabel.text = @"";
		}
		[self.headerView addSubview:self.cacheSizeLabel];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
		[self updateCacheSizeLabel];
		
		self.deleteSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.deleteSongsButton.frame = CGRectMake(0, y, 160, 50);
		self.deleteSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		[self.deleteSongsButton addTarget:self action:@selector(deleteSongsAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.deleteSongsButton];
		
		self.editSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, y, 160, 50)];
		self.editSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.editSongsLabel.backgroundColor = [UIColor clearColor];
		self.editSongsLabel.textColor = [UIColor whiteColor];
		self.editSongsLabel.textAlignment = NSTextAlignmentCenter;
		self.editSongsLabel.font = ISMSBoldFont(22);
		self.editSongsLabel.text = @"Edit";
		[self.headerView addSubview:self.editSongsLabel];
		
		self.editSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.editSongsButton.frame = CGRectMake(160, y, 160, 40);
		self.editSongsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		[self.editSongsButton addTarget:self action:@selector(editSongsAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.editSongsButton];	
		
		self.deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 160, 50)];
		self.deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		self.deleteSongsLabel.textColor = [UIColor whiteColor];
		self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
		self.deleteSongsLabel.font = ISMSBoldFont(22);
		self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
		self.deleteSongsLabel.text = @"Delete # Songs";
		self.deleteSongsLabel.hidden = YES;
		[self.headerView addSubview:self.deleteSongsLabel];
		
		self.headerView2 = nil;
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			self.headerView2 = [[UIView alloc] initWithFrame:CGRectMake(0, y + 52, 320, 50)];
			self.headerView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			self.headerView2.backgroundColor = viewObjectsS.darkNormal;
			[self.headerView addSubview:self.headerView2];
			
			self.playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
			self.playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			self.playAllLabel.backgroundColor = [UIColor clearColor];
			self.playAllLabel.textColor = ISMSHeaderButtonColor;
			self.playAllLabel.textAlignment = NSTextAlignmentCenter;
			self.playAllLabel.font = ISMSRegularFont(24);
			self.playAllLabel.text = @"Play All";
			[self.headerView2 addSubview:self.playAllLabel];
			
			self.playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
			self.playAllButton.frame = CGRectMake(0, 0, 160, 40);
			self.playAllButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			[self.playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
			[self.headerView2 addSubview:self.playAllButton];
			
			self.shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
			self.shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
			self.shuffleLabel.backgroundColor = [UIColor clearColor];
			self.shuffleLabel.textColor = ISMSHeaderButtonColor;
			self.shuffleLabel.textAlignment = NSTextAlignmentCenter;
			self.shuffleLabel.font = ISMSRegularFont(24);
			self.shuffleLabel.text = @"Shuffle";
			[self.headerView2 addSubview:self.shuffleLabel];
			
			self.shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
			self.shuffleButton.frame = CGRectMake(160, 0, 160, 40);
			self.shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
			[self.shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
			[self.headerView2 addSubview:self.shuffleButton];
		}
		
		self.tableView.tableHeaderView = self.headerView;
	}
}

- (void)removeNoSongsScreen
{
	if (self.isNoSongsScreenShowing == YES)
	{
		[self.noSongsScreen removeFromSuperview];
		self.isNoSongsScreenShowing = NO;
	}
}

- (void)addNoSongsScreen
{
	[self removeNoSongsScreen];
	
	if (self.isNoSongsScreenShowing == NO)
	{		
		self.isNoSongsScreenShowing = YES;
		self.noSongsScreen = [[UIImageView alloc] init];
		self.noSongsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noSongsScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noSongsScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noSongsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.noSongsScreen.alpha = .80;
		self.noSongsScreen.userInteractionEnabled = YES;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isCacheUnlocked)
		{
			if (self.segmentedControl.selectedSegmentIndex == 0)
				[textLabel setText:@"No Cached\nSongs"];
			else if (self.segmentedControl.selectedSegmentIndex == 1)
				[textLabel setText:@"No Queued\nSongs"];
			
			textLabel.frame = CGRectMake(20, 20, 200, 140);
		}
		else
		{
			textLabel.text = @"Caching\nLocked";
			textLabel.frame = CGRectMake(20, 0, 200, 100);
		}
		[self.noSongsScreen addSubview:textLabel];
		
		if (settingsS.isCacheUnlocked == NO)
		{
			UILabel *textLabel2 = [[UILabel alloc] init];
			textLabel2.backgroundColor = [UIColor clearColor];
			textLabel2.textColor = [UIColor whiteColor];
			textLabel2.font = ISMSBoldFont(14);
			textLabel2.textAlignment = NSTextAlignmentCenter;
			textLabel2.numberOfLines = 0;
			textLabel2.text = @"Tap to purchase the ability to cache songs for better streaming performance and offline playback";
			textLabel2.frame = CGRectMake(20, 90, 200, 70);
			[self.noSongsScreen addSubview:textLabel2];
			
			UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
			storeLauncher.frame = CGRectMake(0, 0, self.noSongsScreen.frame.size.width, self.noSongsScreen.frame.size.height);
			[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
			[self.noSongsScreen addSubview:storeLauncher];
		}
		
		[self.view addSubview:self.noSongsScreen];
		
		
		if (!IS_IPAD())
		{
			if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				self.noSongsScreen.transform = CGAffineTransformTranslate(self.noSongsScreen.transform, 0.0, 23.0);
			}
		}
	}
}

- (void) showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		self.deleteSongsLabel.text = @"Select All";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
			self.deleteSongsLabel.text = @"Delete 1 Folder  ";
		else
			self.deleteSongsLabel.text = @"Delete 1 Song  ";
	}
	else
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)[viewObjectsS.multiDeleteList count]];
		else
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
	
	self.songsCountLabel.hidden = YES;
	self.cacheSizeLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}


- (void)hideDeleteButton
{
	if (!self.tableView.editing)
	{
		self.songsCountLabel.hidden = NO;
		self.cacheSizeLabel.hidden = NO;
		self.deleteSongsLabel.hidden = YES;
		return;
	}
	
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		self.deleteSongsLabel.text = @"Select All";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		
		if (self.segmentedControl.selectedSegmentIndex == 0)
			self.deleteSongsLabel.text = @"Delete 1 Folder  ";
		else
			self.deleteSongsLabel.text = @"Delete 1 Song  ";
	}
	else 
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)[viewObjectsS.multiDeleteList count]];
		else
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
}


- (void)showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		if ([cell respondsToSelector:@selector(deleteToggleImage)])
		{
			if ([[cell deleteToggleImage] respondsToSelector:@selector(setHidden:)])
			{
				[[cell deleteToggleImage] setHidden:NO];
			}
		}
	}
}

- (void)editSongsAction:(id)sender
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (!self.tableView.editing)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			self.editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			self.editSongsLabel.text = @"Done";
			[self showDeleteButton];
			
			[self performSelector:@selector(showDeleteToggle) withObject:nil afterDelay:0.3];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editSongsLabel.backgroundColor = [UIColor clearColor];
			self.editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self.tableView reloadData];
		}
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		if (!self.tableView.editing)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			self.editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			self.editSongsLabel.text = @"Done";
			[self showDeleteButton];
			
			[self performSelector:@selector(showDeleteToggle) withObject:nil afterDelay:0.3];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editSongsLabel.backgroundColor = [UIColor clearColor];
			self.editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self reloadTable];
		}
	}
}

- (void)deleteRowsAtIndexPathsWithAnimation:(NSArray *)indexes
{
	@try
	{
		[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
	}
	@catch (NSException *exception) 
	{
	//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
	}
    
    if (segmentedControl.selectedSegmentIndex == 0)
    {
        [self segmentAction:nil];
    }
}

- (void)deleteCachedSongs
{	
	[self unregisterForNotifications];
	
	NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
	for (NSString *folderName in viewObjectsS.multiDeleteList)
	{
		[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", folderName];
			
			while ([result next])
			{
				@autoreleasepool 
				{
					NSString *md5 = [result stringForColumnIndex:0];
					if (md5) [songMd5s addObject:md5];
				}
			}
			[result close];
		}];
	}	
			
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			[ISMSSong removeSongFromCacheDbQueueByMD5:md5];
		}
	}
	
	[self segmentAction:nil];
	
	[cacheS findCacheSize];
	
	[viewObjectsS hideLoadingScreen];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	[self registerForNotifications];
}

- (void)deleteQueuedSongs
{
	[self unregisterForNotifications];
	
	//NSDate *date = [NSDate date];
	// Sort the multiDeleteList to make sure it's accending
	[viewObjectsS.multiDeleteList sortUsingSelector:@selector(compare:)];
	//DLog(@"1: %f", [[NSDate date] timeIntervalSinceDate:date]);
	//date = [NSDate date];
		
	// Delete each song from the database
	for (NSString *md5 in viewObjectsS.multiDeleteList)
	{
		//NSDate *inside = [NSDate date];
		if (cacheQueueManagerS.isQueueDownloading)
		{
			// Check if we're deleting the song that's currently caching. If so, stop the download.
			if (cacheQueueManagerS.currentQueuedSong)
			{
				if ([[cacheQueueManagerS.currentQueuedSong.path md5] isEqualToString:md5])
				{
					[cacheQueueManagerS stopDownloadQueue];
				}
			}
		}
		
		// Delete the row from the cacheQueue
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", md5];
		}];
		
		//DLog(@"inside: %f", [[NSDate date] timeIntervalSinceDate:inside]);
	}
		
	//DLog(@"2: %f", [[NSDate date] timeIntervalSinceDate:date]);
	//date = [NSDate date];
		
	// Reload the table
	[self editSongsAction:nil];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	[viewObjectsS hideLoadingScreen];
	
	[self registerForNotifications];
}

- (void)deleteSongsAction:(id)sender
{
	if (self.tableView.editing)
	{
		if ([self.deleteSongsLabel.text isEqualToString:@"Select All"])
		{
			if (self.segmentedControl.selectedSegmentIndex == 0)
			{
				// Select all the rows
				for (NSArray *section in self.listOfArtistsSections)
				{
					for (NSString *folderName in section)
					{
						//DLog(@"folderName: %@", folderName);
						[viewObjectsS.multiDeleteList addObject:folderName];
					}
				}
			}
			else
			{
				// Select all the rows
				[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
				{
					FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cacheQueueList"];
					while ([result next])
					{
						@autoreleasepool 
						{
							NSString *md5 = [result stringForColumnIndex:0];
							if (md5) [viewObjectsS.multiDeleteList addObject:md5];
						}
					}
				}];
			}
			
			[self.tableView reloadData];
			[self showDeleteButton];
		}
		else
		{
			[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
			if (self.segmentedControl.selectedSegmentIndex == 0)
				[self performSelector:@selector(deleteCachedSongs) withObject:nil afterDelay:0.05];
			else
				[self performSelector:@selector(deleteQueuedSongs) withObject:nil afterDelay:0.05];
		}
	}
}

- (void)playAllPlaySong
{	
	[musicS playSongAtPosition:0];
	
	[self showPlayer];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (self.segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		//DLog(@"sectionInfo count: %i", [self.sectionInfo count]);
		return [self.sectionInfo count];
	}
	
	return 1;
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if (self.segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked && self.showIndex)
	{
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (int i = 0; i < [self.sectionInfo count]; i++)
		{
			[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
		}
		return indexes;
	}
		
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if (self.segmentedControl.selectedSegmentIndex == 0 && settingsS.isCacheUnlocked)
	{
		return [[self.sectionInfo objectAtIndexSafe:section] objectAtIndexSafe:0];
	}
	
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		/*if (index == 0)
		{
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
		}
		else
		{
			NSUInteger row = [[[sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
			[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
		}*/
		
		if (index == 0) 
		{
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
			return -1;
		}
		
		return index;
	}
	
	return -1;
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
		return 44.0;
	else
		return 80.0;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (settingsS.isCacheUnlocked)
	{
		// Return the number of rows in the section.
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			//return [listOfArtists count];
			return [[self.listOfArtistsSections objectAtIndexSafe:section] count];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			return self.cacheQueueCount;
		}
	}
	
	return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *cellIdentifier = @"CacheArtistCell";
		CacheArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}

		NSString *name = [[listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
		
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:name])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		if (self.showIndex)
			cell.isIndexShowing = YES;
		
		// Set up the cell...
		[cell.artistNameLabel setText:name];
		
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"CacheQueueCell";
		CacheQueueSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CacheQueueSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.indexPath = indexPath;

		__block ISMSSong *aSong;
		__block NSDate *cached;
		
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue JOIN cacheQueueList USING(md5) WHERE cacheQueueList.ROWID = ?", @(indexPath.row + 1)];
			aSong = [ISMSSong songFromDbResult:result];
			cached = [NSDate dateWithTimeIntervalSince1970:[result doubleForColumn:@"cachedDate"]];
			cell.md5 = [result stringForColumn:@"md5"];
			[result close];
		}];
		
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:cell.md5])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		cell.coverArtView.coverArtId = aSong.coverArtId;
		
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		if (indexPath.row == 0)
		{
			if ([aSong isEqualToSong:cacheQueueManagerS.currentQueuedSong] && cacheQueueManagerS.isQueueDownloading)
			{
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: %@", [NSString relativeTime:cached], [NSString formatFileSize:cacheQueueManagerS.currentQueuedSong.localFileSize]];
			}
			else if (appDelegateS.isWifi || settingsS.isManualCachingOnWWANEnabled)
			{
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
			}
			else
			{
				cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Need Wifi", [NSString relativeTime:cached]];
			}
		}
		else
		{
			cell.cacheInfoLabel.text = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cached]];
		}
		
		cell.songNameLabel.text = aSong.title;
		if (aSong.album)
			cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
		else
			cell.artistNameLabel.text = aSong.artist;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		
		return cell;
	}
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
	//return UITableViewCellEditingStyleDelete;
}


#pragma mark -
#pragma mark Table view delegate

NSInteger trackSort1(id obj1, id obj2, void *context)
{
	NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
	if (track1 < track2)
		return NSOrderedAscending;
	else if (track1 == track2)
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
    if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (viewObjectsS.isCellEnabled)
		{
			NSString *name = nil;
			if ([self.listOfArtistsSections count] > indexPath.section)
				if ([[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] count] > indexPath.row)
					name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
			
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = name;
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
			//DLog(@"cacheAlbumViewController.seg1: %@", cacheAlbumViewController.seg1);
			
			[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
			{
				FMResultSet *result = [db executeQuery:@"SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE", name];
				while ([result next])
				{
					@autoreleasepool 
					{
						NSUInteger numOfSegments = [result intForColumnIndex:1];
						
						NSString *md5 = [result stringForColumn:@"md5"];
						NSString *seg2 = [result stringForColumn:@"seg2"];
						
						if (numOfSegments > 2)
						{
							if (md5 && seg2)
								[cacheAlbumViewController.listOfAlbums addObject:@[md5, seg2]];
						}
						else
						{
							if (md5)
							{
								[cacheAlbumViewController.listOfSongs addObject:@[md5, @([result intForColumn:@"track"])]];
								
								/*// Sort by track number -- iOS 4.0+ only
								 [cacheAlbumViewController.listOfSongs sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
								 NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
								 NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
								 if (track1 < track2)
								 return NSOrderedAscending;
								 else if (track1 == track2)
								 return NSOrderedSame;
								 else
								 return NSOrderedDescending;
								 }];*/
								
								BOOL multipleSameTrackNumbers = NO;
								NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:[cacheAlbumViewController.listOfSongs count]];
								for (NSArray *song in cacheAlbumViewController.listOfSongs)
								{
									NSNumber *track = [song objectAtIndexSafe:1];
									
									if ([trackNumbers containsObject:track])
									{
										multipleSameTrackNumbers = YES;
										break;
									}
									
									[trackNumbers addObject:track];
								}
								
								// Sort by track number
								if (!multipleSameTrackNumbers)
									[cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort1 context:NULL];
							}
						}
					}
					
					if (!cacheAlbumViewController.segments)
					{
						NSArray *segments = @[name];
						cacheAlbumViewController.segments = segments;				
					}
				}
				[result close];
			}];
			
			[self pushViewControllerCustom:cacheAlbumViewController];
			//[self.navigationController pushViewController:cacheAlbumViewController animated:YES];
		}
		else
		{
			[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
		}
	}
}

@end

