//
//  CacheOfflineFoldersViewController.m
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "CacheOfflineFoldersViewController.h"
#import "CacheAlbumViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "CacheSingleton.h"
#import "DatabaseSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation CacheOfflineFoldersViewController

#pragma mark Rotation handling

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    if (!UIDevice.isPad && self.isNoSongsScreenShowing) {
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
}

- (void)unregisterForNotifications {
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_StreamHandlerSongDownloaded];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CacheQueueSongDownloaded];
	[NSNotificationCenter removeObserverOnMainThread:self name:@"cachedSongDeleted"];
}

- (void)viewDidLoad  {
	[super viewDidLoad];
    
    self.title = @"Artists";
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsAction:)];
	
    [self addHeader];
    	    
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
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
    __weak CacheOfflineFoldersViewController *weakSelf = self;
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

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
		
	[self registerForNotifications];
				
	[Flurry logEvent:@"CacheTab"];
	
	// Reload the data in case it changed
    [self reloadTable];
    
    if (self.listOfArtists.count == 0) {
        [self addNoSongsScreen];
    } else {
        [self removeNoSongsScreen];
    }
    	
	self.tableView.scrollEnabled = YES;
    
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
    if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"music.quarternote.3"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}    
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self unregisterForNotifications];
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
    // TODO: implement this
//    PlayQueue.shared.isShuffle = NO;
//	
//    [databaseS resetCurrentPlaylistDb];
//	
//	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
//	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//		FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE"];
//		while ([result next]) {
//			@autoreleasepool {
//				NSString *md5 = [result stringForColumnIndex:0];
//				if (md5) [songMd5s addObject:md5];
//			}
//		}
//		[result close];
//	}];
//	
//	for (NSString *md5 in songMd5s) {
//		@autoreleasepool {
//			ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
//			[aSong addToCurrentPlaylistDbQueue];
//		}
//	}
//	
//	if (shuffle) {
//		PlayQueue.shared.isShuffle = YES;
//		[databaseS shufflePlaylist];
//	} else {
//		PlayQueue.shared.isShuffle = NO;
//	}
//    
//	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
//	
//	// Must do UI stuff in main thread
//	[viewObjectsS hideLoadingScreen];
//	[self playAllPlaySong];	
}

- (void)reloadTable {
    // TODO: implement this
//    // Create the artist list
//    self.listOfArtists = [NSMutableArray arrayWithCapacity:1];
//    self.listOfArtistsSections = [NSMutableArray arrayWithCapacity:28];
//
//    // Fix for slow load problem (EDIT: Looks like it didn't actually work :(
//    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistList"];
//        [db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)"];
//        [db executeUpdate:@"INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout"];
//
//        FMResultSet *result = [db executeQuery:@"SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE"];
//        while ([result next]) {
//            @autoreleasepool {
//                // Cover up for blank insert problem
//                NSString *artist = [result stringForColumnIndex:0];
//                if (artist.length > 0) {
//                    [self.listOfArtists addObject:[artist copy]];
//                }
//            }
//        }
//        [result close];
//
//        [self.listOfArtists sortUsingSelector:@selector(caseInsensitiveCompareWithoutIndefiniteArticles:)];
//        //DLog(@"listOfArtists: %@", listOfArtists);
//
//        // Create the section index
//        [db executeUpdate:@"DROP TABLE IF EXISTS cachedSongsArtistIndex"];
//        [db executeUpdate:@"CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)"];
//        //DLog(@"listOfArtists: %@", self.listOfArtists);
//        for (NSString *artist in self.listOfArtists) {
//            [db executeUpdate:@"INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", [artist stringWithoutIndefiniteArticle], nil];
//        }
//    }];
//
//    self.sectionInfo = [databaseS sectionInfoFromTable:@"cachedSongsArtistIndex" inDatabaseQueue:databaseS.songCacheDbQueue withColumn:@"artist"];
//    self.showIndex = YES;
//    if ([self.sectionInfo count] < 5) {
//        self.showIndex = NO;
//    }
//
//    // Sort into sections
//    if ([self.sectionInfo count] > 0) {
//        int lastIndex = 0;
//        for (int i = 0; i < [self.sectionInfo count] - 1; i++) {
//            @autoreleasepool {
//                int index = [[[self.sectionInfo objectAtIndexSafe:i+1] objectAtIndexSafe:1] intValue];
//                NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
//                for (int i = lastIndex; i < index; i++) {
//                    [section addObject:[self.listOfArtists objectAtIndexSafe:i]];
//                }
//                [self.listOfArtistsSections addObject:section];
//                lastIndex = index;
//            }
//        }
//        NSMutableArray *section = [NSMutableArray arrayWithCapacity:0];
//        for (int i = lastIndex; i < [self.listOfArtists count]; i++) {
//            [section addObject:[self.listOfArtists objectAtIndexSafe:i]];
//        }
//        [self.listOfArtistsSections addObject:section];
//    }
//
//    NSUInteger cachedSongsCount = [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''"];
//    if (cachedSongsCount == 0) {
//        [self addNoSongsScreen];
//    } else {
//        [self removeNoSongsScreen];
//    }
//
//	[self.tableView reloadData];
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
		self.noSongsScreen.image = [UIImage imageNamed:@"loading-screen-image"];
		self.noSongsScreen.alpha = .80;
		self.noSongsScreen.userInteractionEnabled = YES;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.textColor = UIColor.whiteColor;
		textLabel.font = [UIFont boldSystemFontOfSize:30];
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
        textLabel.text = @"No Cached\nSongs";
        textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noSongsScreen addSubview:textLabel];
		
		[self.view addSubview:self.noSongsScreen];
		
		if (!UIDevice.isPad) {
			if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
				self.noSongsScreen.transform = CGAffineTransformTranslate(self.noSongsScreen.transform, 0.0, 23.0);
			}
		}
	}
}

- (void)playAllPlaySong {
	[musicS playSongAtPosition:0];
	
	[self showPlayer];
}

#pragma mark Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionInfo.count;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	if (self.showIndex) {
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (int i = 0; i < self.sectionInfo.count; i++) {
			[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
		}
		return indexes;
	}
		
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[self.sectionInfo objectAtIndexSafe:section] objectAtIndexSafe:0];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
    if (index == 0) {
        [tableView scrollRectToVisible:CGRectMake(0, 90, 320, 40) animated:NO];
        return -1;
    }
    
    return index;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.listOfArtistsSections objectAtIndexSafe:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideCacheIndicator = YES;
    cell.hideNumberLabel = YES;
    cell.hideCoverArt = YES;
    cell.hideSecondaryLabel = YES;
    cell.hideDurationLabel = YES;
    NSString *name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
    [cell updateWithModel:[[ISMSFolderArtist alloc] initWithServerId: -1 folderId:-1 name:name]];
    return cell;
}

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
    // TODO: implement this
//	if (!indexPath) return;
//
//    NSString *name = nil;
//    if ([self.listOfArtistsSections count] > indexPath.section) {
//        if ([[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] count] > indexPath.row) {
//            name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
//        }
//    }
//
//    CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] init];
//    cacheAlbumViewController.artistName = name;
//    cacheAlbumViewController.albums = [NSMutableArray arrayWithCapacity:1];
//    cacheAlbumViewController.songs = [NSMutableArray arrayWithCapacity:1];
//
//    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet *result = [db executeQuery:@"SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE", name];
//        while ([result next]) {
//            @autoreleasepool {
//                NSUInteger numOfSegments = [result intForColumnIndex:1];
//
//                NSString *md5 = [result stringForColumn:@"md5"];
//                NSString *seg2 = [result stringForColumn:@"seg2"];
//
//                if (numOfSegments > 2) {
//                    if (md5 && seg2) {
//                        [cacheAlbumViewController.albums addObject:@[md5, seg2]];
//                    }
//                } else {
//                    if (md5) {
//                        [cacheAlbumViewController.songs addObject:@[md5, @([result intForColumn:@"track"])]];
//
//                        /*// Sort by track number -- iOS 4.0+ only
//                         [cacheAlbumViewController.listOfSongs sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
//                         NSUInteger track1 = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
//                         NSUInteger track2 = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
//                         if (track1 < track2)
//                         return NSOrderedAscending;
//                         else if (track1 == track2)
//                         return NSOrderedSame;
//                         else
//                         return NSOrderedDescending;
//                         }];*/
//
//                        BOOL multipleSameTrackNumbers = NO;
//                        NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:cacheAlbumViewController.songs.count];
//                        for (NSArray *song in cacheAlbumViewController.songs) {
//                            NSNumber *track = [song objectAtIndexSafe:1];
//
//                            if ([trackNumbers containsObject:track]) {
//                                multipleSameTrackNumbers = YES;
//                                break;
//                            }
//
//                            [trackNumbers addObject:track];
//                        }
//
//                        // Sort by track number
//                        if (!multipleSameTrackNumbers) {
//                            [cacheAlbumViewController.songs sortUsingFunction:trackSort context:NULL];
//                        }
//                    }
//                }
//            }
//
//            if (!cacheAlbumViewController.segments) {
//                NSArray *segments = @[name];
//                cacheAlbumViewController.segments = segments;
//            }
//        }
//        [result close];
//    }];
//
//    [self pushViewControllerCustom:cacheAlbumViewController];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // TODO: implement this
//    // Custom queue and delete actions
//    NSString *name = [[self.listOfArtistsSections objectAtIndexSafe:indexPath.section] objectAtIndexSafe:indexPath.row];
//    return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
//        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
//        [EX2Dispatch runInBackgroundAsync:^{
//            NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
//            [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//                FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", name];
//                while ([result next]) {
//                    @autoreleasepool {
//                        NSString *md5 = [result stringForColumnIndex:0];
//                        if (md5) [songMd5s addObject:md5];
//                    }
//                }
//                [result close];
//            }];
//
//            for (NSString *md5 in songMd5s) {
//                @autoreleasepool {
//                    [[ISMSSong songFromCacheDbQueue:md5] addToCurrentPlaylistDbQueue];
//                }
//            }
//
//            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
//
//            [EX2Dispatch runInMainThreadAsync:^{
//                [viewObjectsS hideLoadingScreen];
//            }];
//        }];
//    } deleteHandler:^{
//        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
//        [EX2Dispatch runInBackgroundAsync:^{
//            NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
//            [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//                FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", name];
//                while ([result next]) {
//                    @autoreleasepool {
//                        NSString *md5 = [result stringForColumnIndex:0];
//                        if (md5) [songMd5s addObject:md5];
//                    }
//                }
//                [result close];
//            }];
//
//            for (NSString *md5 in songMd5s) {
//                @autoreleasepool {
//                    [ISMSSong removeSongFromCacheDbByMD5:md5];
//                }
//            }
//
//            [cacheS findCacheSize];
//
//            // Reload the cached songs table
//            [NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
//
//            if (!cacheQueueManagerS.isQueueDownloading) {
//                [cacheQueueManagerS startDownloadQueue];
//            }
//
//            [EX2Dispatch runInMainThreadAsync:^{
//                [viewObjectsS hideLoadingScreen];
//            }];
//        }];
//    }];
    return nil;
}

@end

