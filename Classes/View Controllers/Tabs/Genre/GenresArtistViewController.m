//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresArtistViewController.h"
#import "GenresAlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
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

@implementation GenresArtistViewController

- (void)viewDidLoad  {
    [super viewDidLoad];
        
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
    __weak GenresArtistViewController *weakSelf = self;
    PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [EX2Dispatch runInMainThreadAsync:^{
            [weakSelf playAllSongs];
        }];
    } shuffleHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
        [EX2Dispatch runInMainThreadAsync:^{
            [weakSelf shuffleSongs];
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
    
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)showPlayer {
	// Start the player	
	[musicS playSongAtPosition:0];
	
	if (UIDevice.isIPad) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	} else {
        PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
        playerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:playerViewController animated:YES];
	}
}

- (void)playAllSongs {
	// Turn off shuffle mode in case it's on
	playlistS.isShuffle = NO;
	
	// Reset the current playlist
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode) {
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	} else {
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		// Get the ID of all matching records (everything in genre ordered by artist)
		FMResultSet *result = [db executeQuery:query, self.title];
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
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
    if (settingsS.isJukeboxEnabled) {
		[jukeboxS playSongAtPosition:@0];
    }
    
	// Hide loading screen
	[viewObjectsS hideLoadingScreen];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Show the player
	[self showPlayer];
}

- (void)shuffleSongs {
	// Turn off shuffle mode to reduce inserts
	playlistS.isShuffle = NO;
	
	// Reset the current playlist
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Get the ID of all matching records (everything in genre ordered by artist)
	FMDatabaseQueue *dbQueue;
	NSString *query;
	if (settingsS.isOfflineMode) {
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
    } else {
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query, self.title];
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
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	// Shuffle the playlist
	[databaseS shufflePlaylist];
	
    if (settingsS.isJukeboxEnabled) {
		[jukeboxS playSongAtPosition:@0];
    }
    
	// Set the isShuffle flag
	playlistS.isShuffle = YES;
	
	// Hide loading screen
	[viewObjectsS hideLoadingScreen];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Show the player
	[self showPlayer];
}

#pragma mark Table view methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return [self.listOfArtists count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideCoverArt = YES;
    cell.hideNumberLabel = YES;
    cell.hideDurationLabel = YES;
    cell.hideSecondaryLabel = YES;
    
    NSString *name = [self.listOfArtists objectAtIndexSafe:indexPath.row];
    [cell updateWithPrimaryText:name secondaryText:nil];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
    GenresAlbumViewController *genresAlbumViewController = [[GenresAlbumViewController alloc] initWithNibName:@"GenresAlbumViewController" bundle:nil];
    genresAlbumViewController.title = [self.listOfArtists objectAtIndexSafe:indexPath.row];
    genresAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
    genresAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
    genresAlbumViewController.segment = 2;
    genresAlbumViewController.seg1 = [self.listOfArtists objectAtIndexSafe:indexPath.row];
    genresAlbumViewController.genre = [NSString stringWithString:self.title];
    
    FMDatabaseQueue *dbQueue;
    NSString *query;
    if (settingsS.isOfflineMode) {
        dbQueue = databaseS.songCacheDbQueue;
        query = @"SELECT md5, segs, seg2 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE";
    } else {
        dbQueue = databaseS.genresDbQueue;
        query = @"SELECT md5, segs, seg2 FROM genresLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE";
    }
    
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:query, [self.listOfArtists objectAtIndexSafe:indexPath.row], self.title];
        while ([result next]) {
            @autoreleasepool  {
                NSString *md5 = [result stringForColumnIndex:0];
                NSInteger segs = [result intForColumnIndex:1];
                NSString *seg2 = [result stringForColumnIndex:2];
                
                if (segs > 2) {
                    if (md5 && seg2) {
                        [genresAlbumViewController.listOfAlbums addObject:@[md5, seg2]];
                    }
                } else {
                    if (md5) {
                        [genresAlbumViewController.listOfSongs addObject:md5];
                    }
                }
            }
        }
        [result close];
    }];
    
    [self pushViewControllerCustom:genresAlbumViewController];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = [self.listOfArtists objectAtIndexSafe:indexPath.row];
    if (settingsS.isOfflineMode) {
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.songCacheDbQueue;
                NSString *query = @"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name, self.title];
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
                        ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
                        [aSong addToCurrentPlaylistDbQueue];
                    }
                }
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                [viewObjectsS hideLoadingScreen];
            }];
        } deleteHandler:nil];
    } else {
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.genresDbQueue;
                NSString *query = @"SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name, self.title];
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
                        ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
                        [aSong addToCacheQueueDbQueue];
                    }
                }
                
                // Hide the loading screen
                [viewObjectsS hideLoadingScreen];
            }];
        } queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.genresDbQueue;
                NSString *query = @"SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name, self.title];
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
                        ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
                        [aSong addToCurrentPlaylistDbQueue];
                    }
                }
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                [viewObjectsS hideLoadingScreen];
            }];
        } deleteHandler:nil];
    }
}

@end
