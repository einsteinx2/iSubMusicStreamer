//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresAlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "PlayQueueSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation GenresAlbumViewController

@synthesize listOfAlbums, listOfSongs, segment, seg1, genre;

- (void)viewDidLoad  {
    [super viewDidLoad];
	
	//DLog(@"segment %i", segment);
	//DLog(@"listOfAlbums: %@", listOfAlbums);
	//DLog(@"listOfSongs: %@", listOfSongs);
    
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
    __weak GenresAlbumViewController *weakSelf = self;
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
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"music.quarternote.3"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
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
	if (UIDevice.isPad) {
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
	
	// Get the ID of all matching records (everything in genre ordered by artist)
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode) {
		dbQueue = databaseS.songCacheDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	} else {
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query, self.seg1, self.title, self.genre];
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
	
	[musicS playSongAtPosition:0];
	
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
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	} else {
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query, self.seg1, self.title, self.genre];
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
	
	[musicS playSongAtPosition:0];
	
	// Set the isShuffle flag
	playlistS.isShuffle = YES;
	
	// Hide loading screen
	[viewObjectsS hideLoadingScreen];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Show the player
	[self showPlayer];
}

//- (void)playAllAction:(id)sender {
//	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
//	
//	[self performSelector:@selector(playAllSongs) withObject:nil afterDelay:0.05];
//}
//
//- (void)shuffleAction:(id)sender {
//	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
//	
//	[self performSelector:@selector(shuffleSongs) withObject:nil afterDelay:0.05];
//}


#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return ([self.listOfAlbums count] + [self.listOfSongs count]);
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
    // TODO: Handle genre "fake" albums
    if (indexPath.row < listOfAlbums.count) {
        // Album
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = NO;
        cell.hideSecondaryLabel = YES;
        
        NSString *md5 = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0];
        NSString *coverArtId;
        if (settingsS.isOfflineMode) {
            coverArtId = [databaseS.songCacheDbQueue stringForQuery:@"SELECT coverArtId FROM genresSongs WHERE md5 = ?", md5];
        }
        else {
            coverArtId = [databaseS.genresDbQueue stringForQuery:@"SELECT coverArtId FROM genresSongs WHERE md5 = ?", md5];
        }
        NSString *name = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
        [cell updateWithPrimaryText:name secondaryText:nil coverArtId:coverArtId];
        return cell;
    } else {
        // Song
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        cell.hideCoverArt = YES;
        cell.hideDurationLabel = NO;
        cell.hideSecondaryLabel = NO;
        NSString *md5 = [listOfSongs objectAtIndexSafe:(indexPath.row - listOfAlbums.count)];
        ISMSSong *song = [ISMSSong songFromGenreDbQueue:md5];
        [cell updateWithModel:song];
        if (song.track == nil || song.track.intValue == 0) {
            cell.hideNumberLabel = YES;
        } else {
            cell.hideNumberLabel = NO;
            cell.number = song.track.intValue;
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
    if (indexPath.row < [listOfAlbums count]) {
        GenresAlbumViewController *genresAlbumViewController = [[GenresAlbumViewController alloc] initWithNibName:@"GenresAlbumViewController" bundle:nil];
        genresAlbumViewController.title = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
        genresAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
        genresAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
        genresAlbumViewController.segment = (self.segment + 1);
        genresAlbumViewController.seg1 = self.seg1;
        genresAlbumViewController.genre = [NSString stringWithString:genre];
        
        FMDatabaseQueue *dbQueue;
        NSString *query;
        if (settingsS.isOfflineMode) {
            dbQueue = databaseS.songCacheDbQueue;
            query = [NSString stringWithFormat:@"SELECT md5, segs, seg%li FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? GROUP BY seg%li ORDER BY seg%li COLLATE NOCASE", (long)(segment + 1), (long)segment, (long)(segment + 1), (long)(segment + 1)];
        } else {
            dbQueue = databaseS.genresDbQueue;
            query = [NSString stringWithFormat:@"SELECT md5, segs, seg%li FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? GROUP BY seg%li ORDER BY seg%li COLLATE NOCASE", (long)(segment + 1), (long)segment, (long)(segment + 1), (long)(segment + 1)];
        }
        
        [dbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *result = [db executeQuery:query, self.seg1, [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1], self.genre];
            while ([result next]) {
                @autoreleasepool {
                    NSString *md5 = [result stringForColumnIndex:0];
                    NSInteger segs = [result intForColumnIndex:1];
                    NSString *seg = [result stringForColumnIndex:2];
                    
                    if (segs > (self.segment + 1)) {
                        if (md5 && seg) {
                            [genresAlbumViewController.listOfAlbums addObject:@[md5, seg]];
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
    } else {
        // Find the new playlist position
        NSUInteger songRow = indexPath.row - listOfAlbums.count;
        
        // Clear the current playlist
        if (settingsS.isJukeboxEnabled) {
            [databaseS resetJukeboxPlaylist];
            [jukeboxS clearRemotePlaylist];
        } else {
            [databaseS resetCurrentPlaylistDb];
        }
        
        // Add the songs to the playlist
        NSMutableArray *songIds = [[NSMutableArray alloc] init];
        for (NSString *songMD5 in listOfSongs) {
            @autoreleasepool {
                ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:songMD5];

                [aSong addToCurrentPlaylistDbQueue];
                
                // In jukebox mode, collect the song ids to send to the server
                if (settingsS.isJukeboxEnabled)
                    [songIds addObject:aSong.songId];
            
            }
        }
        
        // If jukebox mode, send song ids to server
        if (settingsS.isJukeboxEnabled) {
            [jukeboxS stop];
            [jukeboxS clearPlaylist];
            [jukeboxS addSongs:songIds];
        }
        
        // Set player defaults
        playlistS.isShuffle = NO;
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
        
        // Start the song
        ISMSSong *playedSong = [musicS playSongAtPosition:songRow];
        if (!playedSong.isVideo) {
            [self showPlayer];
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
    if (settingsS.isOfflineMode) {
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.songCacheDbQueue;
                NSString *query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, self.seg1, name, self.genre];
                    while ([result next]) {
                        @autoreleasepool  {
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
                NSString *query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, self.seg1, name, self.genre];
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
                NSString *query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, self.seg1, name, self.genre];
                    while ([result next]) {
                        @autoreleasepool  {
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
