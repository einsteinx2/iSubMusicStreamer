//
//  BookmarksViewController.m
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BookmarksViewController.h"
#import "BookmarkUITableViewCell.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation BookmarksViewController

#pragma mark - View lifecycle

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	//DLog(@"Cache viewDidLoad");
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
	self.isNoBookmarksScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Bookmarks";
	
	if (settingsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
    
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
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	
	self.tableView.tableHeaderView = nil;
	
	if (self.isNoBookmarksScreenShowing == YES)
	{
		[self.noBookmarksScreen removeFromSuperview];
		self.isNoBookmarksScreenShowing = NO;
	}
	
	NSUInteger bookmarksCount = [databaseS.bookmarksDbQueue intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
	if (bookmarksCount == 0)
	{
		self.isNoBookmarksScreenShowing = YES;
		self.noBookmarksScreen = [[UIImageView alloc] init];
		self.noBookmarksScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noBookmarksScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noBookmarksScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noBookmarksScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.noBookmarksScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isOfflineMode) {
			[textLabel setText:@"No Offline\nBookmarks"];
		}
		else {
			[textLabel setText:@"No Saved\nBookmarks"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noBookmarksScreen addSubview:textLabel];
		
		[self.view addSubview:self.noBookmarksScreen];
		
	}
	else
	{
		// Add the header
		self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
		
		self.bookmarkCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 232, 50)];
		self.bookmarkCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.bookmarkCountLabel.backgroundColor = [UIColor clearColor];
		self.bookmarkCountLabel.textColor = [UIColor whiteColor];
		self.bookmarkCountLabel.textAlignment = NSTextAlignmentCenter;
		self.bookmarkCountLabel.font = ISMSBoldFont(22);
		if (bookmarksCount == 1)
			self.bookmarkCountLabel.text = [NSString stringWithFormat:@"1 Bookmark"];
		else 
			self.bookmarkCountLabel.text = [NSString stringWithFormat:@"%lu Bookmarks", (unsigned long)bookmarksCount];
		[self.headerView addSubview:self.bookmarkCountLabel];
		
		self.deleteBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.deleteBookmarksButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.deleteBookmarksButton.frame = CGRectMake(0, 0, 232, 50);
		[self.deleteBookmarksButton addTarget:self action:@selector(deleteBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.deleteBookmarksButton];
		
		self.editBookmarksLabel = [[UILabel alloc] initWithFrame:CGRectMake(232, 0, 88, 50)];
		self.editBookmarksLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.editBookmarksLabel.backgroundColor = [UIColor clearColor];
		self.editBookmarksLabel.textColor = [UIColor whiteColor];
		self.editBookmarksLabel.textAlignment = NSTextAlignmentCenter;
		self.editBookmarksLabel.font = ISMSBoldFont(22);
		self.editBookmarksLabel.text = @"Edit";
		[self.headerView addSubview:self.editBookmarksLabel];
		
		self.editBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.editBookmarksButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.editBookmarksButton.frame = CGRectMake(232, 0, 88, 40);
		[self.editBookmarksButton addTarget:self action:@selector(editBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.editBookmarksButton];	
		
		self.deleteBookmarksLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 232, 50)];
		self.deleteBookmarksLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.deleteBookmarksLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		self.deleteBookmarksLabel.textColor = [UIColor whiteColor];
		self.deleteBookmarksLabel.textAlignment = NSTextAlignmentCenter;
		self.deleteBookmarksLabel.font = ISMSBoldFont(22);
		self.deleteBookmarksLabel.adjustsFontSizeToFitWidth = YES;
		self.deleteBookmarksLabel.minimumScaleFactor = 12.0 / self.deleteBookmarksLabel.font.pointSize;
		self.deleteBookmarksLabel.text = @"Remove # Bookmarks";
		self.deleteBookmarksLabel.hidden = YES;
		[self.headerView addSubview:self.deleteBookmarksLabel];
		
		self.tableView.tableHeaderView = self.headerView;
	}
	
	[self loadBookmarkIds];
	
	[self.tableView reloadData];
	
	[Flurry logEvent:@"BookmarksTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	self.bookmarkIds = nil;
}

- (void)loadBookmarkIds
{
	NSMutableArray *bookmarkIdsTemp = [[NSMutableArray alloc] initWithCapacity:0];
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT bookmarkId FROM bookmarks"];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *bookmarkId = [result objectForColumnIndex:0];
				if (bookmarkId) [bookmarkIdsTemp addObject:bookmarkId];
			}
		}
		[result close];
	}];
	
	self.bookmarkIds = [NSArray arrayWithArray:bookmarkIdsTemp];
}

- (void)showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		self.deleteBookmarksLabel.text = @"Clear Bookmarks";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		self.deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else
	{
		self.deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %lu Bookmarks", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
	
	self.bookmarkCountLabel.hidden = YES;
	self.deleteBookmarksLabel.hidden = NO;
}


- (void)hideDeleteButton
{
	if (viewObjectsS.multiDeleteList.count == 0)
	{
		if (!self.tableView.editing)
		{
			self.bookmarkCountLabel.hidden = NO;
			self.deleteBookmarksLabel.hidden = YES;
		}
		else
		{
			self.deleteBookmarksLabel.text = @"Clear Bookmarks";
		}
	}
	else if (viewObjectsS.multiDeleteList.count == 1)
	{
		self.deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	}
	else 
	{
		self.deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %lu Bookmarks", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
}



- (void)editBookmarksAction:(id)sender
{
	if (self.tableView.editing == NO)
	{
		[self.tableView reloadData];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		[self.tableView setEditing:YES animated:YES];
		self.editBookmarksLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		self.editBookmarksLabel.text = @"Done";
		[self showDeleteButton];
		
		[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
	}
	else 
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		[self hideDeleteButton];
		[self.tableView setEditing:NO animated:YES];
		self.editBookmarksLabel.backgroundColor = [UIColor clearColor];
		self.editBookmarksLabel.text = @"Edit";
		
		// Reload the table
		//[self.tableView reloadData];
		[self viewWillAppear:NO];
	}
}


- (void)showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}


- (void)deleteBookmarksAction:(id)sender
{
	if ([self.deleteBookmarksLabel.text isEqualToString:@"Clear Bookmarks"])
	{
		[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarks"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}];
				
		[self editBookmarksAction:nil];
		
		// Reload table data
		[self viewWillAppear:NO];
	}
	else
	{
		for (NSNumber *index in viewObjectsS.multiDeleteList)
		{
			NSNumber *bookmarkId = [self.bookmarkIds objectAtIndex:[index intValue]];
			[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
			{
				 [db executeUpdate:@"DELETE FROM bookmarks WHERE bookmarkId = ?", bookmarkId];
			}];
		}
		
		[self loadBookmarkIds];
		
		// Create indexPaths from multiDeleteList
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjectsS.multiDeleteList)
		{
			[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
		}
		
		@try
		{
			[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
		}
		@catch (NSException *exception) 
		{
		//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
		
		
		[self editBookmarksAction:nil];
	}
}


/*// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	// Move the bookmark
	NSInteger fromRow = fromIndexPath.row + 1;
	NSInteger toRow = toIndexPath.row + 1;
	
	[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
	[databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
		
	if (fromRow < toRow)
	{
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
		
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	else
	{
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
		[databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
		
		[databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
		[databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
	}
	
	
	// Fix the multiDeleteList to reflect the new row positions
	//DLog(@"multiDeleteList: %@", viewObjectsS.multiDeleteList);
	if ([viewObjectsS.multiDeleteList count] > 0)
	{
		NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
		int newPosition;
		for (NSNumber *position in viewObjectsS.multiDeleteList)
		{
			if (fromIndexPath.row > toIndexPath.row)
			{
				if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] + 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
			else
			{
				if ([position intValue] <= toIndexPath.row && [position intValue] >= fromIndexPath.row)
				{
					if ([position intValue] == fromIndexPath.row)
					{
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:toIndexPath.row]];
					}
					else 
					{
						newPosition = [position intValue] - 1;
						[tempMultiDeleteList addObject:[NSNumber numberWithInt:newPosition]];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
		}
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
		[tempMultiDeleteList release];
	}
	//DLog(@"multiDeleteList: %@", viewObjectsS.multiDeleteList);
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}*/

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
	//return UITableViewCellEditingStyleDelete;
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return self.bookmarkIds.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"BookmarkCell";
	BookmarkUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[BookmarkUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	cell.indexPath = indexPath;
	
	cell.deleteToggleImage.hidden = !self.tableView.editing;
	cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	if ([viewObjectsS.multiDeleteList containsObject:@(indexPath.row)])
	{
		cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
    // Set up the cell...
	__block ISMSSong *aSong;
	__block NSString *name = nil;
	__block int position = 0;
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
		aSong = [ISMSSong songFromDbResult:result];
		name = [result stringForColumn:@"name"];
		position = [result intForColumn:@"position"];
		[result close];
	}];
		
	cell.coverArtView.coverArtId = aSong.coverArtId;
    
    cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
	[cell.bookmarkNameLabel setText:[NSString stringWithFormat:@"%@ - %@", name, [NSString formatTime:(float)position]]];
	
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	playlistS.isShuffle = NO;
	
	__block NSUInteger bookmarkId = 0;
	__block NSUInteger playlistIndex = 0;
	__block NSUInteger offsetSeconds = 0;
	__block NSUInteger offsetBytes = 0;
	__block ISMSSong *aSong;
	
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
		aSong = [ISMSSong songFromDbResult:result];
		bookmarkId = [result intForColumn:@"bookmarkId"];
		playlistIndex = [result intForColumn:@"playlistIndex"];
		offsetSeconds = [result intForColumn:@"position"];
		offsetBytes = [result intForColumn:@"bytes"];
		[result close];
	}];
		
	// See if there's a playlist table for this bookmark
	if ([databaseS.bookmarksDbQueue tableExists:[NSString stringWithFormat:@"bookmark%lu", (unsigned long)bookmarkId]])
	{		
		// Save the playlist
		NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
		NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		NSString *table = playlistS.isShuffle ? shufTable : currTable;
	//DLog(@"loading table: %@", table);
		
		[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
			
			[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylistDb.%@ SELECT * FROM bookmark%lu", table, (unsigned long)bookmarkId]];
			
			[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}];
		
		if (settingsS.isJukeboxEnabled)
			[jukeboxS jukeboxReplacePlaylistWithLocal];
	}
	else 
	{
		[aSong addToCurrentPlaylistDbQueue];
	}
	
	playlistS.currentIndex = playlistIndex;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
		
	[self showPlayer];
	
	// Check if these are old bookmarks and don't have byteOffset saved
	if (offsetBytes == 0 && offsetSeconds != 0)
	{
		// By default, use the server reported bitrate
		NSUInteger bitrate = [aSong.bitRate intValue];
		
		if (aSong.transcodedSuffix)
		{
			// This is a transcode, guess the bitrate and byteoffset
			NSUInteger maxBitrate = settingsS.currentMaxBitrate == 0 ? 128 : settingsS.currentMaxBitrate;
			bitrate = maxBitrate < [aSong.bitRate intValue] ? maxBitrate : [aSong.bitRate intValue];
		}

		// Use the bitrate to get byteoffset
		offsetBytes = BytesForSecondsAtBitrate(offsetSeconds, bitrate);
	}
	
	if (settingsS.isJukeboxEnabled)
		[musicS playSongAtPosition:playlistIndex];
	else
		[musicS startSongAtOffsetInBytes:offsetBytes andSeconds:offsetSeconds];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


@end

