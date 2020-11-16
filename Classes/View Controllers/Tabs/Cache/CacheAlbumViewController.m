//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheAlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "ISMSAlbum.h"
#import "ISMSCacheQueueManager.h"
#import "CacheSingleton.h"
#import "ISMSSong+DAO.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation CacheAlbumViewController

static NSInteger trackSort(id obj1, id obj2, void *context) {
	NSUInteger track1TrackNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2TrackNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
    NSUInteger track1DiscNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:2] intValue];
    NSUInteger track2DiscNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:2] intValue];
    
    // first check the disc numbers.  if t1d < t2d, ascending
    if (track1DiscNum < track2DiscNum) {
        return NSOrderedAscending;
    }
    
    // if they're equal, check the track numbers
    else if (track1DiscNum == track2DiscNum) {
        if (track1TrackNum < track2TrackNum) {
            return NSOrderedAscending;
        } else if (track1TrackNum == track2TrackNum) {
            return NSOrderedSame;
        } else {
            return NSOrderedDescending;
        }
    }
    
    // if t1d > t2d, descending
	else return NSOrderedDescending;
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    self.title = self.artistName;

	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
    
    self.tableView.rowHeight = 60.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
		
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}

    [self addHeaderAndIndex];
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cachedSongDeleted) name:@"cachedSongDeleted" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cachedSongDeleted" object:nil];
}

- (void)addHeaderAndIndex {
    // Create the container view and constrain it to the table
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.tableHeaderView = headerView;
    [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor].active = YES;
    [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor].active = YES;
    [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor].active = YES;
    
    // Create the play all and shuffle buttons and constrain to the container view
    __weak CacheAlbumViewController *weakSelf = self;
    PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [EX2Dispatch runInBackgroundAsync:^{
            [weakSelf loadPlayAllPlaylist:NO];
        }];
    } shuffleHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
        [EX2Dispatch runInBackgroundAsync:^{
            [weakSelf loadPlayAllPlaylist:YES];
        }];
    }];
    [headerView addSubview:playAllAndShuffleHeader];
    [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor].active = YES;
    [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor].active = YES;
    [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor].active = YES;
    [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor].active = YES;
    
    // Force re-layout using the constraints
    [self.tableView.tableHeaderView layoutIfNeeded];
    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
    
    // Create the section index
    if (self.listOfAlbums.count > 10) {
        __block NSArray *secInfo = nil;
        [databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"DROP TABLE IF EXSITS albumIndex"];
            [db executeUpdate:@"CREATE TEMP TABLE albumIndex (album TEXT)"];
            
            [db beginTransaction];
            for (NSNumber *rowId in self.listOfAlbums) {
                @autoreleasepool {
                    [db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid = ?", rowId];
                }
            }
            [db commit];
            
            secInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"album"];
            [db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
        }];
        
        if (secInfo) {
            self.sectionInfo = [NSArray arrayWithArray:secInfo];
            if ([self.sectionInfo count] < 5) {
                self.sectionInfo = nil;
            } else {
                [self.tableView reloadData];
            }
        } else {
            self.sectionInfo = nil;
        }
    }
}

- (void)cachedSongDeleted {
	NSUInteger segment = self.segments.count;
	
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:1];
	
	NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%lu, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", (long)(segment+1)];
	for (int i = 2; i <= segment; i++) {
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"GROUP BY seg%lu ORDER BY seg%lu COLLATE NOCASE", (long)(segment+1), (long)(segment+1)];
	
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query withArgumentsInArray:self.segments];
		while ([result next]) {
			@autoreleasepool {
				NSString *md5 = [result stringForColumnIndex:0];
				NSInteger segs = [result intForColumnIndex:1];
				NSString *seg = [result stringForColumnIndex:2];
				NSInteger track = [result intForColumnIndex:3];
                NSInteger discNumber = [result intForColumn:@"discNumber"];
				
				if (segs > (segment + 1)) {
					if (md5 && seg) {
                        NSArray *albumEntry = @[md5, seg];
						[self.listOfAlbums addObject:albumEntry];
					}
				} else {
					if (md5) {
                        NSArray *songEntry = @[md5, @(track), @(discNumber)];
						[self.listOfSongs addObject:songEntry];
						
						BOOL multipleSameTrackNumbers = NO;
						NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:self.listOfSongs.count];
						for (NSArray *song in self.listOfSongs) {
							NSNumber *track = [song objectAtIndexSafe:1];
							
							if ([trackNumbers containsObject:track]) {
								multipleSameTrackNumbers = YES;
								break;
							}
							
							if (track)
								[trackNumbers addObject:track];
						}
						
						// Sort by track number
                        if (!multipleSameTrackNumbers) {
							[self.listOfSongs sortUsingFunction:trackSort context:NULL];
                        }
					}
				}
			}
		}
		[result close];
	}];
	
	// If the table is empty, pop back one view, otherwise reload the table data
	if (self.listOfAlbums.count + self.listOfSongs.count == 0) {
		if (UIDevice.isIPad) {
			// TODO: implement this properly
			//[appDelegateS.ipadRootViewController.stackScrollViewController popToRootViewController];
		} else {
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4) {
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			} else {
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
	} else {
		[self.tableView reloadData];
	}
}

- (void)loadPlayAllPlaylist:(BOOL)shuffle {
	NSUInteger segment = [self.segments count];
		
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	NSMutableString *query = [NSMutableString stringWithString:@"SELECT md5 FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "];
	for (int i = 2; i <= segment; i++) {
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendString:@"ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8 COLLATE NOCASE"];
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:50];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:query withArgumentsInArray:self.segments];
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
		
		[databaseS resetShufflePlaylist];
		[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		}];
	} else {
		playlistS.isShuffle = NO;
	}
			
	// Must do UI stuff in main thread
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^ {
        [viewObjectsS hideLoadingScreen];
        [musicS playSongAtPosition:0];
        if (UIDevice.isIPad) {
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
        } else {
            PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
            playerViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:playerViewController animated:YES];
        }
    }];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Table view methods

- (ISMSAlbum *)albumAtIndexPath:(NSIndexPath *)indexPath {
    NSString *md5 = [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0];
    ISMSAlbum *album = [[ISMSAlbum alloc] init];
    album.title = [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
    album.coverArtId = [databaseS.songCacheDbQueue stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", md5];
    album.artistName = self.artistName;
    return album;
}

- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
    NSString *md5 = [[self.listOfSongs objectAtIndexSafe:(indexPath.row - self.listOfAlbums.count)] firstObject];
    return [ISMSSong songFromCacheDbQueue:md5];
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	for (int i = 0; i < self.sectionInfo.count; i++) {
		[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	if (index == 0) {
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
	} else {
		NSUInteger row = [[[self.sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	}
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (self.listOfAlbums.count + self.listOfSongs.count);
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
	if (indexPath.row < self.listOfAlbums.count) {
        // Album
        cell.hideCacheIndicator = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = YES;
        [cell updateWithModel:[self albumAtIndexPath:indexPath]];
	} else {
        // Song
        cell.hideCacheIndicator = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = NO;
        [cell updateWithModel:[self songAtIndexPath:indexPath]];
	}
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
    if (indexPath.row < self.listOfAlbums.count) {
        NSUInteger segment = self.segments.count + 1;
        
        CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
        cacheAlbumViewController.artistName = [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
        cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
        cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];

        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%lu, track, cachedSongs.discNumber FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", (long)(segment+1)];
        for (int i = 2; i <= segment; i++) {
            [query appendFormat:@" AND seg%i = ? ", i];
        }
        [query appendFormat:@"GROUP BY seg%lu ORDER BY seg%lu COLLATE NOCASE", (long)(segment+1), (long)(segment+1)];

        NSMutableArray *newSegments = [NSMutableArray arrayWithArray:self.segments];
        [newSegments addObject:cacheAlbumViewController.artistName];
        cacheAlbumViewController.segments = [NSArray arrayWithArray:newSegments];
        
        [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
            while ([result next]) {
                @autoreleasepool {
                    NSString *md5 = [result stringForColumnIndex:0];
                    NSInteger segs = [result intForColumnIndex:1];
                    NSString *seg = [result stringForColumnIndex:2];
                    NSInteger track = [result intForColumnIndex:3];
                    NSInteger discNumber = [result intForColumn:@"discNumber"];
                    
                    if (segs > (segment + 1)) {
                        if (md5 && seg) {
                            NSArray *albumEntry = @[md5, seg];
                            [cacheAlbumViewController.listOfAlbums addObject:albumEntry];
                        }
                    } else {
                        if (md5) {
                            NSMutableArray *songEntry = [NSMutableArray arrayWithObjects:md5, @(track), nil];
                            
                            if (discNumber != 0) {
                                [songEntry addObject:@(discNumber)];
                            }
                            
                            [cacheAlbumViewController.listOfSongs addObject:songEntry];
                            
                            BOOL multipleSameTrackNumbers = NO;
                            NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:cacheAlbumViewController.listOfSongs.count];
                            for (NSArray *song in cacheAlbumViewController.listOfSongs) {
                                NSNumber *track = [song objectAtIndexSafe:1];
                                NSNumber *disc = [song objectAtIndexSafe:2];
                                
                                // Wow, that got messy quick.  In the second part we're checking that the entry at the index
                                // of the object we found doesn't have the same disc number as the one we're about to add.  If
                                // it does, we have a problem, but if not, we can add it anyway and let the sort method sort it
                                // out.  Hahah.  See what I did there?
                                if ([trackNumbers containsObject:track] && (disc == nil || [[cacheAlbumViewController.listOfSongs[[trackNumbers indexOfObject:track]] objectAtIndexSafe:2] isEqual:disc])) {
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
            }
            [result close];
        }];
        
        [self pushViewControllerCustom:cacheAlbumViewController];
    } else {
        NSUInteger a = indexPath.row - self.listOfAlbums.count;
        
        if (settingsS.isJukeboxEnabled) {
            [databaseS resetJukeboxPlaylist];
            [jukeboxS clearRemotePlaylist];
        } else {
            [databaseS resetCurrentPlaylistDb];
        }
        for (NSArray *song in self.listOfSongs) {
            ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:[song objectAtIndexSafe:0]];
            [aSong addToCurrentPlaylistDbQueue];
        }
                    
        playlistS.isShuffle = NO;
        
        [musicS playSongAtPosition:a];
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
        
        [self showPlayer];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.listOfAlbums.count) {
        // Custom queue and delete actions
        ISMSAlbum *album = [self albumAtIndexPath:indexPath];
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInBackgroundAsync:^{
                NSMutableArray *newSegments = [NSMutableArray arrayWithArray:self.segments];
                [newSegments addObject:album.title];
                
                NSUInteger segment = [newSegments count];
                
                NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE segs = %lu", (unsigned long)(segment+1)];
                for (int i = 1; i <= segment; i++) {
                    [query appendFormat:@" AND seg%i = ? ", i];
                }
                [query appendFormat:@"ORDER BY seg%lu COLLATE NOCASE", (long)segment+1];
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:20];
                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
                    while ([result next]) {
                        NSString *md5 = [result stringForColumnIndex:0];
                        if (md5) [songMd5s addObject:md5];
                    }
                    [result close];
                }];
                
                for (NSString *md5 in songMd5s) {
                    @autoreleasepool {
                        ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
                        [aSong addToCurrentPlaylistDbQueue];
                    }
                }
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                [EX2Dispatch runInMainThreadAsync:^{
                    [viewObjectsS hideLoadingScreen];
                }];
            }];
        } deleteHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
            [EX2Dispatch runInBackgroundAsync:^{
                NSMutableArray *newSegments = [NSMutableArray arrayWithArray:self.segments];
                [newSegments addObject:album.title];
                
                NSUInteger segment = [newSegments count];

                NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? "];
                for (int i = 2; i <= segment; i++) {
                    [query appendFormat:@" AND seg%i = ? ", i];
                }
                
                DDLogVerbose(@"query: %@, parameter: %@", query, newSegments);
                NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
                    while ([result next]) {
                        @autoreleasepool {
                            NSString *md5 = [result stringForColumnIndex:0];
                            if (md5) [songMd5s addObject:md5];
                        }
                    }
                    [result close];
                }];
                
                DDLogVerbose(@"songMd5s: %@", songMd5s);
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
        NSString *md5 = [[self.listOfSongs objectAtIndexSafe:(indexPath.row - self.listOfAlbums.count)] firstObject];
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [[ISMSSong songFromCacheDbQueue:md5] addToCurrentPlaylistDbQueue];
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
        } deleteHandler:^{
            [ISMSSong removeSongFromCacheDbQueueByMD5:md5];
            [cacheS findCacheSize];
            // Reload the cached songs table
            [NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
        }];
    }
}

@end
