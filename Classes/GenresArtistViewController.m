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

@implementation GenresArtistViewController

@synthesize listOfArtists;

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	
	//DLog(@"listOfArtists: %@", listOfArtists);
	
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
	[musicS playSongAtPosition:0];
	
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
	
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		// Get the ID of all matching records (everything in genre ordered by artist)
		FMResultSet *result = [db executeQuery:query, self.title];
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
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxPlaySongAtPosition:@0];
	
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
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.title];
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
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxPlaySongAtPosition:@0];
	
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
	return [listOfArtists count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *cellIdentifier = @"GenresArtistCell";
	GenresArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[GenresArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	cell.genre = self.title;
	
	NSString *name = [listOfArtists objectAtIndexSafe:indexPath.row];
	
	[cell.artistNameLabel setText:name];
    
    cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
    
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		GenresAlbumViewController *genresAlbumViewController = [[GenresAlbumViewController alloc] initWithNibName:@"GenresAlbumViewController" bundle:nil];
		genresAlbumViewController.title = [listOfArtists objectAtIndexSafe:indexPath.row];
		genresAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
		genresAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];
		genresAlbumViewController.segment = 2;
		genresAlbumViewController.seg1 = [listOfArtists objectAtIndexSafe:indexPath.row];
		genresAlbumViewController.genre = [NSString stringWithString:self.title];
		
		FMDatabaseQueue *dbQueue;
		NSString *query;
		if (settingsS.isOfflineMode)
		{
			dbQueue = databaseS.songCacheDbQueue;
			query = @"SELECT md5, segs, seg2 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE";
		}
		else
		{
			dbQueue = databaseS.genresDbQueue;
			query = @"SELECT md5, segs, seg2 FROM genresLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE";
		}
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:query, [listOfArtists objectAtIndexSafe:indexPath.row], self.title];
			while ([result next])
			{
				@autoreleasepool 
				{
					NSString *md5 = [result stringForColumnIndex:0];
					NSInteger segs = [result intForColumnIndex:1];
					NSString *seg2 = [result stringForColumnIndex:2];
					
					if (segs > 2)
					{
						if (md5 && seg2)
							[genresAlbumViewController.listOfAlbums addObject:@[md5, seg2]];
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
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


@end

