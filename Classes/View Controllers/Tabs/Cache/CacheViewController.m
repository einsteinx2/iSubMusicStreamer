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
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "CacheSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "ISMSArtist.h"
#import "AsynchronousImageView.h"

@interface CacheViewController ()
@property NSUInteger cacheQueueCount;
@end

@implementation CacheViewController

#pragma mark Rotation handling

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    if (!UIDevice.isIPad && self.isNoSongsScreenShowing) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (UIInterfaceOrientationIsPortrait(UIApplication.orientation)) {
                self.noSongsScreen.transform = CGAffineTransformTranslate(self.noSongsScreen.transform, 0.0, 110.0);
            } else {
                self.noSongsScreen.transform = CGAffineTransformTranslate(self.noSongsScreen.transform, 0.0, -23.0);
            }
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { }];
    }

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - View lifecycle

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)registerForNotifications {
	// Set notification receiver for when queued songs finish downloading to reload the table
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadTable) name:ISMSNotification_StreamHandlerSongDownloaded];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadTable) name:ISMSNotification_CacheQueueSongDownloaded];
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadTable) name:@"cachedSongDeleted"];
	
	// Set notification receiver for when network status changes to reload the table
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(segmentAction:) name:EX2ReachabilityNotification_ReachabilityChanged];
}

- (void)unregisterForNotifications {
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_StreamHandlerSongDownloaded];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CacheQueueSongDownloaded];
	[NSNotificationCenter removeObserverOnMainThread:self name:@"cachedSongDeleted"];
	[NSNotificationCenter removeObserverOnMainThread:self name:EX2ReachabilityNotification_ReachabilityChanged];
}

- (void)viewDidLoad  {
	[super viewDidLoad];
	
	self.cacheSizeLabel = nil;
	
	self.jukeboxInputBlocker = nil;
	
	self.isNoSongsScreenShowing = NO;
	self.isSaveEditShowing = NO;
    
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];

    self.segmentControlContainer = [[UIView alloc] init];
    self.segmentControlContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
	self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Cached", @"Downloading"]];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	self.segmentedControl.selectedSegmentIndex = 0;

    [self.segmentControlContainer addSubview:self.segmentedControl];
    [self.view addSubview:self.segmentControlContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControlContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:7],
        [self.segmentControlContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:5],
        [self.segmentControlContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-5],
        [self.segmentControlContainer.heightAnchor constraintEqualToConstant:36],
        
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.segmentControlContainer.topAnchor],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.segmentControlContainer.leadingAnchor],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.segmentControlContainer.trailingAnchor]
    ]];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableViewTopConstraint = [self.tableView.topAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        self.tableViewTopConstraint,
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.tableView registerClass:BlurredSectionHeader.class forHeaderFooterViewReuseIdentifier:BlurredSectionHeader.reuseId];
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
	
    self.title = @"Cache";
    
    // Setup the update timer
    [self updateQueueDownloadProgress];
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
		
	[self registerForNotifications];
		
	[self reloadTable];
	
	[self updateQueueDownloadProgress];
	[self updateCacheSizeLabel];
	
	[Flurry logEvent:@"CacheTab"];
	
	// Reload the data in case it changed
    self.tableView.tableHeaderView.hidden = NO;
    [self segmentAction:nil];
	
	self.tableView.scrollEnabled = YES;
	[self.jukeboxInputBlocker removeFromSuperview];
	self.jukeboxInputBlocker = nil;
	if (settingsS.isJukeboxEnabled) {
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
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}    
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	// Must do this here as well or the no songs overlay will be off sometimes
    self.tableView.tableHeaderView.hidden = NO;
    [self segmentAction:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
		
	[self unregisterForNotifications];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
}

- (void)segmentAction:(id)sender {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (self.isEditing) {
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if (self.listOfArtists.count == 0) {
			[self removeSaveEditButtons];
			[self addNoSongsScreen];
		} else {
			[self removeNoSongsScreen];
            [self addSaveEditButtons];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
		if (self.isEditing) {
			[self editSongsAction:nil];
		}
		
		[self reloadTable];
		
		if (self.cacheQueueCount > 0) {
			[self removeNoSongsScreen];
			[self addSaveEditButtons];
		}
	}
	
	[self.tableView reloadData];
}

#pragma mark Button Handling

- (void)settingsAction:(id)sender  {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)loadPlayAllPlaylist:(BOOL)shuffle {
    playlistS.isShuffle = NO;
	
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE"];
		while ([result next]) {
			@autoreleasepool {
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s) {
		@autoreleasepool {
			ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	if (shuffle) {
		playlistS.isShuffle = YES;
		[databaseS shufflePlaylist];
	} else {
		playlistS.isShuffle = NO;
	}
	
    if (settingsS.isJukeboxEnabled) {
		[jukeboxS playSongAtPosition:@(0)];
    }
    
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Must do UI stuff in main thread
	[viewObjectsS hideLoadingScreen];
	[self playAllPlaySong];	
}

- (void)reloadTable {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		// Create the artist list
		self.listOfArtists = [NSMutableArray arrayWithCapacity:1];
		self.listOfArtistsSections = [NSMutableArray arrayWithCapacity:28];
		
		// Fix for slow load problem (EDIT: Looks like it didn't actually work :(
		[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistList"];
			[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
			[db executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
			
			FMResultSet *result = [db executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
            while ([result next]) {
				@autoreleasepool {
					// Cover up for blank insert problem
					NSString *artist = [result stringForColumnIndex:0];
                    if (artist.length > 0) {
						[self.listOfArtists addObject:[artist copy]];
                    }
				}
			}
			[result close];
			
			[self.listOfArtists sortUsingSelector:@selector(caseInsensitiveCompareWithoutIndefiniteArticles:)];
			//DLog(@"listOfArtists: %@", listOfArtists);
			
			// Create the section index
			[db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistIndex"];
			[db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)"];
			//DLog(@"listOfArtists: %@", self.listOfArtists);
			for (NSString *artist in self.listOfArtists) {
				[db executeUpdate:@"INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", [artist stringWithoutIndefiniteArticle], nil];
			}
		}];
		
		self.sectionInfo = [databaseS sectionInfoFromTable:@"cachedSongsArtistIndex" inDatabaseQueue:databaseS.songCacheDbQueue withColumn:@"artist"];
		self.showIndex = YES;
        if ([self.sectionInfo count] < 5) {
			self.showIndex = NO;
        }
				
		// Sort into sections		
		if ([self.sectionInfo count] > 0) {
			int lastIndex = 0;
			for (int i = 0; i < [self.sectionInfo count] - 1; i++) {
				@autoreleasepool {
					int index = [[[self.sectionInfo objectAtIndexSafe:i+1] objectAtIndexSafe:1] intValue];
					NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
					for (int i = lastIndex; i < index; i++) {
						[section addObject:[self.listOfArtists objectAtIndexSafe:i]];
					}
					[self.listOfArtistsSections addObject:section];
					lastIndex = index;
				}
			}
			NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
			for (int i = lastIndex; i < [self.listOfArtists count]; i++) {
				[section addObject:[self.listOfArtists objectAtIndexSafe:i]];
			}
			[self.listOfArtistsSections addObject:section];
		}
        
        NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
		if (cachedSongsCount == 0) {
			[self removeSaveEditButtons];
			[self addNoSongsScreen];
			[self addNoSongsScreen];
		} else {
			if (self.isSaveEditShowing) {
                if (cachedSongsCount == 1) {
					self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
                } else {
					self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
                }
			} else {
				[self addSaveEditButtons];
			}
			
			[self removeNoSongsScreen];
		}
	} else {
		self.cacheQueueCount = [databaseS.cacheQueueDbQueue intForQuery:@"SELECT COUNT(*) FROM cacheQueue"];
		if (self.cacheQueueCount == 0) {
			[self removeSaveEditButtons];	
			[self addNoSongsScreen];
			[self addNoSongsScreen];
		} else {
			if (self.isSaveEditShowing) {
                if (self.cacheQueueCount == 1) {
					self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
                } else {
					self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)self.cacheQueueCount];
                }
            } else {
				[self addSaveEditButtons];
			}
			
            if (self.isNoSongsScreenShowing) {
				[self removeNoSongsScreen];
            }
		}
	}
	
	[self.tableView reloadData];
}

- (void)updateCacheSizeLabel {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
        if (cacheS.cacheSize <= 0) {
			self.cacheSizeLabel.text = @"";
        } else {
			self.cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
        }
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
	
	// Call again in a couple seconds
	[self performSelector:@selector(updateCacheSizeLabel) withObject:nil afterDelay:2.0];
}

- (void)updateQueueDownloadProgress {
	if (self.segmentedControl.selectedSegmentIndex == 1 && cacheQueueManagerS.isQueueDownloading) {
		[self reloadTable];
	}
	
	// Make sure this didn't get called multiple times
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
	
	// Call again in a second
	[self performSelector:@selector(updateQueueDownloadProgress) withObject:nil afterDelay:3.];
}

- (void)addHeader {
    // Create the container view and constrain it to the table
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.tableHeaderView = headerView;
    [NSLayoutConstraint activateConstraints:@[
        [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor],
        [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor]
    ]];
    
    // Create the play all and shuffle buttons and constrain to the container view
    __weak CacheViewController *weakSelf = self;
    PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [EX2Dispatch runInMainThreadAsync:^{
            [weakSelf loadPlayAllPlaylist:NO];
        }];
    } shuffleHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
        [EX2Dispatch runInMainThreadAsync:^{
            [weakSelf loadPlayAllPlaylist:YES];
        }];
    }];
    [headerView addSubview:playAllAndShuffleHeader];
    [NSLayoutConstraint activateConstraints:@[
        [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
        [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor],
        [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
    ]];
    
    // Force re-layout using the constraints
    [self.tableView.tableHeaderView layoutIfNeeded];
    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)removeSaveEditButtons {
    if (!self.isSaveEditShowing) return;
    
    self.isSaveEditShowing = NO;
    [self.saveEditContainer removeFromSuperview]; self.saveEditContainer = nil;
    [self.songsCountLabel removeFromSuperview]; self.songsCountLabel = nil;
    [self.deleteSongsButton removeFromSuperview]; self.deleteSongsButton = nil;
    [self.editSongsLabel removeFromSuperview]; self.editSongsLabel = nil;
    [self.editSongsButton removeFromSuperview]; self.editSongsButton = nil;
    [self.deleteSongsLabel removeFromSuperview]; self.deleteSongsLabel = nil;
    [self.cacheSizeLabel removeFromSuperview]; self.cacheSizeLabel = nil;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
    
    self.tableView.tableHeaderView = nil;
    
    self.tableViewTopConstraint.constant = 0;
    [self.tableView setNeedsUpdateConstraints];
}

- (void)addSaveEditButtons {
	[self removeSaveEditButtons];
	
    self.isSaveEditShowing = YES;
    
    self.saveEditContainer = [[UIView alloc] init];
    self.saveEditContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.saveEditContainer];
    
    self.songsCountLabel = [[UILabel alloc] init];
    self.songsCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.songsCountLabel.textColor = UIColor.labelColor;
    self.songsCountLabel.textAlignment = NSTextAlignmentCenter;
    self.songsCountLabel.font = [UIFont boldSystemFontOfSize:22];
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
        if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"] == 1) {
            self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
        } else {
            self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)cachedSongsCount];
        }
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        if (self.cacheQueueCount == 1) {
            self.songsCountLabel.text = [NSString stringWithFormat:@"1 Song"];
        } else {
            self.songsCountLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)self.cacheQueueCount];
        }
    }
    [self.saveEditContainer addSubview:self.songsCountLabel];
    
    self.cacheSizeLabel = [[UILabel alloc] init];
    self.cacheSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.cacheSizeLabel.textColor = UIColor.labelColor;
    self.cacheSizeLabel.textAlignment = NSTextAlignmentCenter;
    self.cacheSizeLabel.font = [UIFont boldSystemFontOfSize:12];
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        if (cacheS.cacheSize <= 0) {
            self.cacheSizeLabel.text = @"";
        } else {
            self.cacheSizeLabel.text = [NSString formatFileSize:cacheS.cacheSize];
        }
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
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
    [self.saveEditContainer addSubview:self.cacheSizeLabel];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCacheSizeLabel) object:nil];
    [self updateCacheSizeLabel];
    
    self.deleteSongsLabel = [[UILabel alloc] init];
    self.deleteSongsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
    self.deleteSongsLabel.textColor = UIColor.labelColor;
    self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
    self.deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
    self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
    self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
    self.deleteSongsLabel.text = @"Delete # Songs";
    self.deleteSongsLabel.hidden = YES;
    [self.saveEditContainer addSubview:self.deleteSongsLabel];
    
    self.deleteSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.deleteSongsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deleteSongsButton addTarget:self action:@selector(deleteSongsAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.deleteSongsButton];
    
    self.editSongsLabel = [[UILabel alloc] init];
    self.editSongsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.editSongsLabel.textColor = UIColor.systemBlueColor;//UIColor.labelColor;
    self.editSongsLabel.textAlignment = NSTextAlignmentCenter;
    self.editSongsLabel.font = [UIFont boldSystemFontOfSize:22];
    self.editSongsLabel.text = @"Edit";
    [self.saveEditContainer addSubview:self.editSongsLabel];
    
    self.editSongsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editSongsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.editSongsButton addTarget:self action:@selector(editSongsAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.editSongsButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.saveEditContainer.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.saveEditContainer.heightAnchor constraintEqualToConstant:50],
        [self.saveEditContainer.topAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor constant:8],
        
        [self.songsCountLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.songsCountLabel.heightAnchor constraintEqualToAnchor:self.saveEditContainer.heightAnchor multiplier:0.666],
        [self.songsCountLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.songsCountLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        
        [self.cacheSizeLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.cacheSizeLabel.heightAnchor constraintEqualToAnchor:self.saveEditContainer.heightAnchor multiplier:0.333],
        [self.cacheSizeLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.cacheSizeLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor constant:-4],
        
        [self.deleteSongsLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.deleteSongsLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.deleteSongsLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.deleteSongsLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.deleteSongsButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.deleteSongsButton.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.deleteSongsButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.deleteSongsButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editSongsLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editSongsLabel.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editSongsLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editSongsLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editSongsButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editSongsButton.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editSongsButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editSongsButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
    ]];
    
    self.tableViewTopConstraint.constant = 58;
    [self.tableView setNeedsUpdateConstraints];
    
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        [self addHeader];
    }
}

- (void)removeNoSongsScreen {
	if (self.isNoSongsScreenShowing == YES) {
		[self.noSongsScreen removeFromSuperview];
		self.isNoSongsScreenShowing = NO;
	}
}

- (void)addNoSongsScreen {
	[self removeNoSongsScreen];
	
	if (self.isNoSongsScreenShowing == NO) {
		self.isNoSongsScreenShowing = YES;
		self.noSongsScreen = [[UIImageView alloc] init];
		self.noSongsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noSongsScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noSongsScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noSongsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.noSongsScreen.alpha = .80;
		self.noSongsScreen.userInteractionEnabled = YES;
		
		UILabel *textLabel = [[UILabel alloc] init];
//		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:30];
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
        if (self.segmentedControl.selectedSegmentIndex == 0) {
            [textLabel setText:@"No Cached\nSongs"];
        } else if (self.segmentedControl.selectedSegmentIndex == 1) {
            [textLabel setText:@"No Queued\nSongs"];
        }
        textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noSongsScreen addSubview:textLabel];
		
		[self.view addSubview:self.noSongsScreen];
		
		if (!UIDevice.isIPad) {
			if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
				self.noSongsScreen.transform = CGAffineTransformTranslate(self.noSongsScreen.transform, 0.0, 23.0);
			}
		}
	}
}

- (void)showDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
		self.deleteSongsLabel.text = @"Select All";
	} else if (selectedRowsCount == 1) {
        if (self.segmentedControl.selectedSegmentIndex == 0) {
			self.deleteSongsLabel.text = @"Delete 1 Folder  ";
        } else {
			self.deleteSongsLabel.text = @"Delete 1 Song  ";
        }
	} else {
        if (self.segmentedControl.selectedSegmentIndex == 0) {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)selectedRowsCount];
        } else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)selectedRowsCount];
        }
	}
	
	self.songsCountLabel.hidden = YES;
	self.cacheSizeLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}

- (void)hideDeleteButton {
	if (!self.isEditing) {
		self.songsCountLabel.hidden = NO;
		self.cacheSizeLabel.hidden = NO;
		self.deleteSongsLabel.hidden = YES;
		return;
	}
	
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
		self.deleteSongsLabel.text = @"Select All";
	} else if (selectedRowsCount == 1) {
        if (self.segmentedControl.selectedSegmentIndex == 0) {
			self.deleteSongsLabel.text = @"Delete 1 Folder  ";
        } else {
			self.deleteSongsLabel.text = @"Delete 1 Song  ";
        }
    } else {
        if (self.segmentedControl.selectedSegmentIndex == 0) {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Folders", (unsigned long)selectedRowsCount];
        } else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Delete %lu Songs", (unsigned long)selectedRowsCount];
        }
	}
}

- (void)editSongsAction:(id)sender {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (!self.isEditing) {
            [self setEditing:YES animated:YES];
			self.editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
            self.editSongsLabel.textColor = UIColor.labelColor;
			self.editSongsLabel.text = @"Done";
			[self showDeleteButton];
        } else {
            [self setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editSongsLabel.backgroundColor = UIColor.clearColor;
            self.editSongsLabel.textColor = UIColor.systemBlueColor;
			self.editSongsLabel.text = @"Edit";
			
			// Reload the table
			[self.tableView reloadData];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
		if (!self.tableView.editing) {
            // Stop table updating out from under selection
            [self unregisterForNotifications];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateQueueDownloadProgress) object:nil];
            
            [self setEditing:YES animated:YES];
			self.editSongsLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
            self.editSongsLabel.textColor = UIColor.labelColor;
			self.editSongsLabel.text = @"Done";
			[self showDeleteButton];
		} else {
            [self setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editSongsLabel.backgroundColor = UIColor.clearColor;
            self.editSongsLabel.textColor = UIColor.systemBlueColor;
			self.editSongsLabel.text = @"Edit";
            
            // Start updating table again
            [self registerForNotifications];
            [self updateQueueDownloadProgress];
			
			// Reload the table
			[self reloadTable];
		}
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

- (void)deleteRowsAtIndexPathsWithAnimation:(NSArray *)indexes {
	@try {
		[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
	} @catch (NSException *exception) {
        //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
	}
    
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        [self segmentAction:nil];
    }
}

- (NSMutableArray<NSString*> *)selectedRowNames {
    NSMutableArray<NSString*> *selectedRowNames = [[NSMutableArray alloc] init];
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            NSString *name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
            [selectedRowNames addObject:name];
        }
    }
    return selectedRowNames;
}

- (NSMutableArray<NSString*> *)selectedRowMD5s {
    NSMutableArray<NSString*> *selectedRowMD5s = [[NSMutableArray alloc] init];
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        for (NSString *folderName in self.selectedRowNames) {
            [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", folderName];
                while ([result next]) {
                    NSString *md5 = [result stringForColumnIndex:0];
                    if (md5) [selectedRowMD5s addObject:md5];
                }
                [result close];
            }];
        }
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            [databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
                FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", @(indexPath.row)];
                if ([result next]) {
                    NSString *md5 = [result stringForColumn:@"md5"];
                    if (md5) [selectedRowMD5s addObject:md5];
                }
                [result close];
            }];
        }
    }
    return selectedRowMD5s;
}

- (void)deleteCachedSongs {
	[self unregisterForNotifications];
			
	for (NSString *md5 in self.selectedRowMD5s) {
		@autoreleasepool {
			[ISMSSong removeSongFromCacheDbQueueByMD5:md5];
		}
	}
	
	[self segmentAction:nil];
	
	[cacheS findCacheSize];
	
	[viewObjectsS hideLoadingScreen];
	
    if (!cacheQueueManagerS.isQueueDownloading) {
		[cacheQueueManagerS startDownloadQueue];
    }
	
	[self registerForNotifications];
}

- (void)deleteQueuedSongs {
  	[self unregisterForNotifications];
	
	// Delete each song from the database
	for (NSString *md5 in self.selectedRowMD5s) {
		//NSDate *inside = [NSDate date];
		if (cacheQueueManagerS.isQueueDownloading) {
			// Check if we're deleting the song that's currently caching. If so, stop the download.
			if (cacheQueueManagerS.currentQueuedSong) {
				if ([[cacheQueueManagerS.currentQueuedSong.path md5] isEqualToString:md5]) {
					[cacheQueueManagerS stopDownloadQueue];
				}
			}
		}
		
		// Delete the row from the cacheQueue
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", md5];
		}];
	}
		
	// Reload the table
	[self editSongsAction:nil];
	
    if (!cacheQueueManagerS.isQueueDownloading) {
		[cacheQueueManagerS startDownloadQueue];
    }
	
	[viewObjectsS hideLoadingScreen];
	
	[self registerForNotifications];
}

- (void)deleteSongsAction:(id)sender {
	if (self.isEditing) {
		if ([self.deleteSongsLabel.text isEqualToString:@"Select All"]) {
			if (self.segmentedControl.selectedSegmentIndex == 0) {
				// Select all the rows
                NSUInteger sectionCount = self.listOfArtistsSections.count;
                for (NSUInteger section = 0; section < sectionCount; section++) {
                    NSUInteger rowCount = [(NSArray*)self.listOfArtistsSections[section] count];
                    for (NSUInteger row = 0; row < rowCount; row++) {
                        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:NO scrollPosition:UITableViewScrollPositionNone];
                    }
                }
			} else {
				// Select all the rows
                NSUInteger rowCount = [databaseS.cacheQueueDbQueue intForQuery:@"SELECT count(*) FROM cacheQueue"];
                for (NSUInteger i = 0; i < rowCount; i++) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
                }
			}
			[self showDeleteButton];
		} else {
			[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
            if (self.segmentedControl.selectedSegmentIndex == 0) {
				[self performSelector:@selector(deleteCachedSongs) withObject:nil afterDelay:0.05];
            } else {
				[self performSelector:@selector(deleteQueuedSongs) withObject:nil afterDelay:0.05];
            }
		}
	}
}

- (void)playAllPlaySong {
	[musicS playSongAtPosition:0];
	
	[self showPlayer];
}

#pragma mark Table view data source

- (ISMSArtist *)artistForIndexPath:(NSIndexPath *)indexPath {
    if (self.segmentedControl.selectedSegmentIndex != 0) return nil;
    
    NSString *name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
    return [ISMSArtist artistWithName:name andArtistId:@""];
}

- (ISMSSong *)songForIndexPath:(NSIndexPath *)indexPath {
    __block ISMSSong *song;
    [databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", @(indexPath.row)];
        song = [ISMSSong songFromDbResult:result];
        [result close];
    }];
    return song;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		return [self.sectionInfo count];
	}
	
	return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.segmentedControl.selectedSegmentIndex == 0 && self.showIndex) {
        BlurredSectionHeader *sectionHeader = [tableView dequeueReusableHeaderFooterViewWithIdentifier:BlurredSectionHeader.reuseId];
        sectionHeader.text = [[self.sectionInfo objectAtIndexSafe:section] objectAtIndexSafe:0];
        return sectionHeader;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.segmentedControl.selectedSegmentIndex == 0 && self.showIndex) {
        return Defines.rowHeight - 5;
    }
    return 0;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	if (self.segmentedControl.selectedSegmentIndex == 0 && self.showIndex) {
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (int i = 0; i < [self.sectionInfo count]; i++) {
			[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
		}
		return indexes;
	}
		
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (index == 0) {
			[tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
			return -1;
		}
		
		return index;
	}
	
	return -1;
}

// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.segmentedControl.selectedSegmentIndex == 0 ? Defines.rowHeight : Defines.tallRowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        return [[self.listOfArtistsSections objectAtIndexSafe:section] count];
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        return self.cacheQueueCount;
    }
    
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        cell.hideHeaderLabel = YES;
        cell.hideCacheIndicator = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = YES;
        cell.hideSecondaryLabel = YES;
        cell.hideDurationLabel = YES;
        [cell updateWithModel:[self artistForIndexPath:indexPath]];
        return cell;
	} else {
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        cell.hideHeaderLabel = NO;
        cell.hideCacheIndicator = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideSecondaryLabel = NO;
        cell.hideDurationLabel = NO;
        
        __block ISMSSong *song;
        __block NSDate *cachedDate;
        [databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", @(indexPath.row)];
            song = [ISMSSong songFromDbResult:result];
            cachedDate = [NSDate dateWithTimeIntervalSince1970:[result doubleForColumn:@"cachedDate"]];
            [result close];
        }];
        
        [cell updateWithModel:song];
        
        if (indexPath.row == 0) {
            NSLog(@"song: %@  currentQueuedSong: %@  isQueueDownloading: %@", song, cacheQueueManagerS.currentQueuedSong, NSStringFromBOOL(cacheQueueManagerS.isQueueDownloading));
            if ([song isEqualToSong:cacheQueueManagerS.currentQueuedSong] && cacheQueueManagerS.isQueueDownloading) {
                cell.headerText = [NSString stringWithFormat:@"Added %@ - Progress: %@", [NSString relativeTime:cachedDate], [NSString formatFileSize:cacheQueueManagerS.currentQueuedSong.localFileSize]];
            } else if (appDelegateS.isWifi || settingsS.isManualCachingOnWWANEnabled) {
                cell.headerText = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cachedDate]];
            } else {
                cell.headerText = [NSString stringWithFormat:@"Added %@ - Progress: Need Wifi", [NSString relativeTime:cachedDate]];
            }
        } else {
            cell.headerText = [NSString stringWithFormat:@"Added %@ - Progress: Waiting...", [NSString relativeTime:cachedDate]];
        }
		return cell;
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
//	return UITableViewCellEditingStyleNone;
	return UITableViewCellEditingStyleDelete;
}

#pragma mark Table view delegate

static NSInteger trackSort(id obj1, id obj2, void *context) {
	NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
    if (track1 < track2) {
		return NSOrderedAscending;
    } else if (track1 == track2) {
		return NSOrderedSame;
    } else {
		return NSOrderedDescending;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath) return;
    
    if (self.isEditing) {
        [self showDeleteButton];
        return;
    }
	
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        NSString *name = nil;
        if ([self.listOfArtistsSections count] > indexPath.section) {
            if ([[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] count] > indexPath.row) {
                name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
            }
        }
        
        CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
        cacheAlbumViewController.artistName = name;
        cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
        cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
        
        [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *result = [db executeQuery:@"SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE", name];
            while ([result next]) {
                @autoreleasepool {
                    NSUInteger numOfSegments = [result intForColumnIndex:1];
                    
                    NSString *md5 = [result stringForColumn:@"md5"];
                    NSString *seg2 = [result stringForColumn:@"seg2"];
                    
                    if (numOfSegments > 2) {
                        if (md5 && seg2) {
                            [cacheAlbumViewController.listOfAlbums addObject:@[md5, seg2]];
                        }
                    } else {
                        if (md5) {
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
                            for (NSArray *song in cacheAlbumViewController.listOfSongs) {
                                NSNumber *track = [song objectAtIndexSafe:1];
                                
                                if ([trackNumbers containsObject:track]) {
                                    multipleSameTrackNumbers = YES;
                                    break;
                                }
                                
                                [trackNumbers addObject:track];
                            }
                            
                            // Sort by track number
                            if (!multipleSameTrackNumbers) {
                                [cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort context:NULL];
                            }
                        }
                    }
                }
                
                if (!cacheAlbumViewController.segments) {
                    NSArray *segments = @[name];
                    cacheAlbumViewController.segments = segments;
                }
            }
            [result close];
        }];
        
        [self pushViewControllerCustom:cacheAlbumViewController];
	}
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    
    if (self.isEditing) {
        [self hideDeleteButton];
    }
}


- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        // Custom queue and delete actions
        ISMSArtist *artist = [self artistForIndexPath:indexPath];
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInBackgroundAsync:^{
                NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", artist.name];
                    while ([result next]) {
                        @autoreleasepool {
                            NSString *md5 = [result stringForColumnIndex:0];
                            if (md5) [songMd5s addObject:md5];
                        }
                    }
                    [result close];
                }];

                for (NSString *md5 in songMd5s) {
                    @autoreleasepool {
                        [[ISMSSong songFromCacheDbQueue:md5] addToCurrentPlaylistDbQueue];
                    }
                }

                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];

                [EX2Dispatch runInMainThreadAsync:^{
                    [viewObjectsS hideLoadingScreen];
                }];
            }];
        } deleteHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInBackgroundAsync:^{
                NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", artist.name];
                    while ([result next]) {
                        @autoreleasepool {
                            NSString *md5 = [result stringForColumnIndex:0];
                            if (md5) [songMd5s addObject:md5];
                        }
                    }
                    [result close];
                }];
                
                for (NSString *md5 in songMd5s) {
                    @autoreleasepool {
                        [ISMSSong removeSongFromCacheDbQueueByMD5:md5];
                    }
                }
                
                [cacheS findCacheSize];
                
                // Reload the cached songs table
                [NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
                
                if (!cacheQueueManagerS.isQueueDownloading) {
                    [cacheQueueManagerS startDownloadQueue];
                }
                
                [EX2Dispatch runInMainThreadAsync:^{
                    [viewObjectsS hideLoadingScreen];
                }];
            }];
        }];
    } else {
        ISMSSong *song = [self songForIndexPath:indexPath];
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [song addToCurrentPlaylistDbQueue];
        } deleteHandler:^{
            [song removeFromCacheQueueDbQueue];
            [self reloadTable];
        }];
    }
}

@end

