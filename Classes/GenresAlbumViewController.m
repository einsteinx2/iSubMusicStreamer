//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresAlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "GenresAlbumUITableViewCell.h"
#import "GenresSongUITableViewCell.h"
#import "AllSongsUITableViewCell.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation GenresAlbumViewController

@synthesize listOfAlbums, listOfSongs, segment, seg1, genre;

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	
	//DLog(@"segment %i", segment);
	//DLog(@"listOfAlbums: %@", listOfAlbums);
	//DLog(@"listOfSongs: %@", listOfSongs);
	
	// Add the play all button + shuffle button
	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
	headerView.backgroundColor = ISMSHeaderColor;
	
	UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
	playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
	playAllLabel.backgroundColor = [UIColor clearColor];
	playAllLabel.textColor = ISMSHeaderButtonColor;
	playAllLabel.textAlignment = NSTextAlignmentCenter;
	playAllLabel.font = ISMSBoldFont(24);
	playAllLabel.text = @"Play All";
	[headerView addSubview:playAllLabel];
	
	UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playAllButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
	playAllButton.frame = CGRectMake(0, 0, 160, 40);
	[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:playAllButton];
    
	UILabel *shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
	shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleLabel.backgroundColor = [UIColor clearColor];
	shuffleLabel.textColor = ISMSHeaderButtonColor;
	shuffleLabel.textAlignment = NSTextAlignmentCenter;
	shuffleLabel.font = ISMSBoldFont(24);
	shuffleLabel.text = @"Shuffle";
	[headerView addSubview:shuffleLabel];
	
	UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
	shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleButton.frame = CGRectMake(160, 0, 160, 40);
	[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:shuffleButton];
	
	self.tableView.tableHeaderView = headerView;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}

	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
		
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}


-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}



- (void)showPlayer
{
	// Start the player		
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	}	
}

- (void)playAllSongs
{	
	// Turn off shuffle mode in case it's on
	playlistS.isShuffle = NO;
	
	// Reset the current playlist
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Get the ID of all matching records (everything in genre ordered by artist)
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, seg1, self.title, genre];
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

- (void)shuffleSongs
{		
	// Turn off shuffle mode to reduce inserts
	playlistS.isShuffle = NO;
	
	// Reset the current playlist
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Get the ID of all matching records (everything in genre ordered by artist)
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)(segment - 1), (long)segment];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, seg1, self.title, genre];
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

- (void)playAllAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	
	[self performSelector:@selector(playAllSongs) withObject:nil afterDelay:0.05];
}

- (void)shuffleAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
	
	[self performSelector:@selector(shuffleSongs) withObject:nil afterDelay:0.05];
}


#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return ([self.listOfAlbums count] + [self.listOfSongs count]);
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row < [listOfAlbums count])
		return 60.0;
	else
		return 50.0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	// Set up the cell...
	if (indexPath.row < [listOfAlbums count])
	{
		static NSString *cellIdentifier = @"GenresAlbumCell";
		GenresAlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[GenresAlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		cell.segment = self.segment;
		cell.seg1 = self.seg1;
		cell.genre = genre;
		
		NSString *md5 = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0];
		NSString *coverArtId;
		if (settingsS.isOfflineMode) {
			coverArtId = [databaseS.songCacheDbQueue stringForQuery:@"SELECT coverArtId FROM genresSongs WHERE md5 = ?", md5];
		}
		else {
			coverArtId = [databaseS.genresDbQueue stringForQuery:@"SELECT coverArtId FROM genresSongs WHERE md5 = ?", md5];
		}
		NSString *name = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
		cell.albumNameLabel.text = name;
	//DLog(@"name: %@", name);
		
		cell.coverArtView.coverArtId = coverArtId;
		
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"GenresSongCell";
		GenresSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[GenresSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		NSUInteger a = indexPath.row - [listOfAlbums count];
		cell.md5 = [listOfSongs objectAtIndexSafe:a];
		
		ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:cell.md5];
		
		if (aSong.track)
		{
			cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
		}
		else
		{	
			cell.trackNumberLabel.text = @"";
		}
			
		cell.songNameLabel.text = aSong.title;
		
		if (aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if (aSong.duration)
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
		if (settingsS.isOfflineMode)
		{
			cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		}
		else
		{
			if (aSong.isFullyCached)
            {
                cell.backgroundView = [[UIView alloc] init];
                cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
            }
            else
            {
                cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
            }
		}
		
		return cell;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (indexPath.row < [listOfAlbums count])
		{		
			GenresAlbumViewController *genresAlbumViewController = [[GenresAlbumViewController alloc] initWithNibName:@"GenresAlbumViewController" bundle:nil];
			genresAlbumViewController.title = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
			genresAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			genresAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
			genresAlbumViewController.segment = (self.segment + 1);
			genresAlbumViewController.seg1 = self.seg1;
			genresAlbumViewController.genre = [NSString stringWithString:genre];
			
			FMDatabaseQueue *dbQueue;
			NSString *query;
			if (settingsS.isOfflineMode)
			{
				dbQueue = databaseS.songCacheDbQueue;
				query = [NSString stringWithFormat:@"SELECT md5, segs, seg%li FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? GROUP BY seg%li ORDER BY seg%li COLLATE NOCASE", (long)(segment + 1), (long)segment, (long)(segment + 1), (long)(segment + 1)];
			}
			else
			{
				dbQueue = databaseS.genresDbQueue;
				query = [NSString stringWithFormat:@"SELECT md5, segs, seg%li FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? GROUP BY seg%li ORDER BY seg%li COLLATE NOCASE", (long)(segment + 1), (long)segment, (long)(segment + 1), (long)(segment + 1)];
			}
			
			[dbQueue inDatabase:^(FMDatabase *db)
			{
				FMResultSet *result = [db executeQuery:query, seg1, [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1], genre];
				while ([result next])
				{
					@autoreleasepool 
					{
						NSString *md5 = [result stringForColumnIndex:0];
						NSInteger segs = [result intForColumnIndex:1];
						NSString *seg = [result stringForColumnIndex:2];
						
						if (segs > (segment + 1))
						{
							if (md5 && seg)
								[genresAlbumViewController.listOfAlbums addObject:@[md5, seg]];
						}
						else
						{
							if (md5)
								[genresAlbumViewController.listOfSongs addObject:md5];
						}
					}
				}
				[result close];
			}];
			
			[self pushViewControllerCustom:genresAlbumViewController];
		}
		else
		{
			// Find the new playlist position
			NSUInteger songRow = indexPath.row - listOfAlbums.count;
			
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
			
			// Add the songs to the playlist 
			NSMutableArray *songIds = [[NSMutableArray alloc] init];
			for(NSString *songMD5 in listOfSongs)
			{
				@autoreleasepool
				{
					ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:songMD5];

					[aSong addToCurrentPlaylistDbQueue];
					
					// In jukebox mode, collect the song ids to send to the server
					if (settingsS.isJukeboxEnabled)
						[songIds addObject:aSong.songId];
				
				}
			}
			
			// If jukebox mode, send song ids to server
			if (settingsS.isJukeboxEnabled)
			{
				[jukeboxS jukeboxStop];
				[jukeboxS jukeboxClearPlaylist];
				[jukeboxS jukeboxAddSongs:songIds];
			}
			
			// Set player defaults
			playlistS.isShuffle = NO;
            
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
			
			// Start the song
            ISMSSong *playedSong = [musicS playSongAtPosition:songRow];
            if (!playedSong.isVideo)
                [self showPlayer];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

