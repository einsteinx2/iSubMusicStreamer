//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresArtistViewController.h"
#import "GenresAlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "GenresArtistUITableViewCell.h"
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
    [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor].active = YES;
    [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor].active = YES;
    [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor].active = YES;
    
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
    [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor].active = YES;
    [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor].active = YES;
    [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor].active = YES;
    [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor].active = YES;
    
    // Force re-layout using the constraints
    [self.tableView.tableHeaderView layoutIfNeeded];
    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
    
//	// Add the play all button + shuffle button
//	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
//	headerView.backgroundColor = ISMSHeaderColor;
//
//	UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
//	playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
//	playAllLabel.backgroundColor = [UIColor clearColor];
//	playAllLabel.textColor = ISMSHeaderButtonColor;
//	playAllLabel.textAlignment = NSTextAlignmentCenter;
//	playAllLabel.font = ISMSBoldFont(24);
//	playAllLabel.text = @"Play All";
//	[headerView addSubview:playAllLabel];
//
//	UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
//	playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
//	playAllButton.frame = CGRectMake(0, 0, 160, 40);
//	[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
//	[headerView addSubview:playAllButton];
//
//	UILabel *shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
//	shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
//	shuffleLabel.backgroundColor = [UIColor clearColor];
//	shuffleLabel.textColor = ISMSHeaderButtonColor;
//	shuffleLabel.textAlignment = NSTextAlignmentCenter;
//	shuffleLabel.font = ISMSBoldFont(24);
//	shuffleLabel.text = @"Shuffle";
//	[headerView addSubview:shuffleLabel];
//
//	UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
//	shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
//	shuffleButton.frame = CGRectMake(160, 0, 160, 40);
//	[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
//	[headerView addSubview:shuffleButton];
//
//	self.tableView.tableHeaderView = headerView;
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
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
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)showPlayer {
	// Start the player	
	[musicS playSongAtPosition:0];
	
	if (UIDevice.isIPad) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	} else {
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	}
}

- (void)playAllSongs {
	// Turn off shuffle mode in case it's on
	playlistS.isShuffle = NO;
	
	// Reset the current playlist
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
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
		[jukeboxS jukeboxPlaySongAtPosition:@0];
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
		[jukeboxS jukeboxClearRemotePlaylist];
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
		[jukeboxS jukeboxPlaySongAtPosition:@0];
    }
    
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return [self.listOfArtists count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"GenresArtistCell";
	GenresArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell) {
		cell = [[GenresArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.genre = self.title;
	
	NSString *name = [self.listOfArtists objectAtIndexSafe:indexPath.row];
	
	[cell.artistNameLabel setText:name];
        
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
	if (viewObjectsS.isCellEnabled) {
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
	} else {
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

@end
