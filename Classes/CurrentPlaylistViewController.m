//
//  CurrentPlaylistViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistViewController.h"
#import "CurrentPlaylistSongSmallUITableViewCell.h"
#import "StoreViewController.h"

@implementation CurrentPlaylistViewController

#pragma mark -
#pragma mark View lifecycle

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxSongInfo) name:ISMSNotification_JukeboxSongInfo object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
		
	//NSDate *start = [NSDate date];	
	self.tableView.backgroundColor = [UIColor clearColor];
	
	if (settingsS.isPlaylistUnlocked)
	{
		[self registerForNotifications];
		
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		//viewObjectsS.multiDeleteList = nil; viewObjectsS.multiDeleteList = [[NSMutableArray alloc] init];
		
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
        
        [self updateCurrentPlaylistCount];
				
		// Setup header view
		self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
		self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
		
		self.savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 232, 34)];
		self.savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
		self.savePlaylistLabel.textColor = [UIColor whiteColor];
		self.savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
		self.savePlaylistLabel.font = ISMSBoldFont(22);
		self.savePlaylistLabel.text = @"Save Playlist";
		[self.headerView addSubview:self.savePlaylistLabel];
		
		self.playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 33, 232, 14)];
		self.playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.playlistCountLabel.backgroundColor = [UIColor clearColor];
		self.playlistCountLabel.textColor = [UIColor whiteColor];
		self.playlistCountLabel.textAlignment = NSTextAlignmentCenter;
		self.playlistCountLabel.font = ISMSBoldFont(12);
		[self.headerView addSubview:self.playlistCountLabel];
		
		self.savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.savePlaylistButton.frame = CGRectMake(0, 0, 232, 40);
		[self.savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.savePlaylistButton];
		
		self.editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(232, 0, 88, 50)];
		self.editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
		self.editPlaylistLabel.textColor = [UIColor whiteColor];
		self.editPlaylistLabel.textAlignment = NSTextAlignmentCenter;
		self.editPlaylistLabel.font = ISMSBoldFont(22);
		self.editPlaylistLabel.text = @"Edit";
		[self.headerView addSubview:self.editPlaylistLabel];
		
		UIButton *editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		editPlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		editPlaylistButton.frame = CGRectMake(232, 0, 88, 40);
		[editPlaylistButton addTarget:self action:@selector(editPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:editPlaylistButton];
		
		self.deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 232, 50)];
		self.deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		self.deleteSongsLabel.textColor = [UIColor whiteColor];
		self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
		self.deleteSongsLabel.font = ISMSBoldFont(22);
		self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
		self.deleteSongsLabel.text = @"Remove # Songs";
		self.deleteSongsLabel.hidden = YES;
		[self.headerView addSubview:self.deleteSongsLabel];
		
		self.tableView.tableHeaderView = self.headerView;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideEditControls) name:@"hideEditControls" object:nil];
	}
	else
	{
		self.tableView.separatorColor = [UIColor clearColor];
		
		UIImageView *noPlaylistsScreen = [[UIImageView alloc] init];
		noPlaylistsScreen.userInteractionEnabled = YES;
		noPlaylistsScreen.frame = CGRectMake(40, 80, 240, 180);
		noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		textLabel.text = @"Playlists\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
		[noPlaylistsScreen addSubview:textLabel];
		
		UILabel *textLabel2 = [[UILabel alloc] init];
		textLabel2.backgroundColor = [UIColor clearColor];
		textLabel2.textColor = [UIColor whiteColor];
		textLabel2.font = ISMSBoldFont(14);
		textLabel2.textAlignment = NSTextAlignmentCenter;
		textLabel2.numberOfLines = 0;
		textLabel2.text = @"Tap to purchase the ability to view, create, and manage playlists";
		textLabel2.frame = CGRectMake(20, 100, 200, 60);
		[noPlaylistsScreen addSubview:textLabel2];
		
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, noPlaylistsScreen.frame.size.width, noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[noPlaylistsScreen addSubview:storeLauncher];
		
		[self.view addSubview:noPlaylistsScreen];
		
	}
	//DLog(@"end: %f", [[NSDate date] timeIntervalSinceDate:start]);
	
	[self.tableView reloadData];
    
    [self selectRow];
}

- (void)showStore
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"player show store"];
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	[self selectRow];
}

- (void)viewWillDisappear:(BOOL)animated 
{
    [super viewWillDisappear:animated];
	
	[self unregisterForNotifications];
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	if (self.tableView.editing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideEditControls" object:nil];
	
	self.headerView = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark -

- (void)jukeboxSongInfo
{
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
	[self selectRow];
}

- (void)songsQueued
{
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
}

- (void)updateCurrentPlaylistCount
{
	self.currentPlaylistCount = [playlistS count];
		
	if (self.currentPlaylistCount == 1)
		self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
	else 
		self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
}

- (void)editPlaylistAction:(id)sender
{
	if (!self.tableView.editing)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		[self.tableView setEditing:YES animated:YES];
		self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		self.editPlaylistLabel.text = @"Done";
		[self showDeleteButton];
		
		// Hide the duration labels and shorten the song and artist labels
		for (CurrentPlaylistSongSmallUITableViewCell *cell in [self.tableView visibleCells])
		{
			cell.durationLabel.hidden = YES;
		}
		
		[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
	}
	else 
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		[self.tableView setEditing:NO animated:YES];
		[self hideDeleteButton];
		self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
		self.editPlaylistLabel.text = @"Edit";
		
		// Reload the table to correct the numbers
		[self.tableView reloadData];

		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
	}
}

- (void) hideEditControls
{
	if (self.tableView.editing == YES)
		[self editPlaylistAction:nil];
}

- (void) showDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		self.deleteSongsLabel.text = @"Clear Playlist";
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		self.deleteSongsLabel.text = @"Remove 1 Song  ";
	}
	else
	{
		self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
	
	self.savePlaylistLabel.hidden = YES;
	self.playlistCountLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}

- (void) hideDeleteButton
{
	if ([viewObjectsS.multiDeleteList count] == 0)
	{
		if (!self.tableView.editing)
		{
			self.savePlaylistLabel.hidden = NO;
			self.playlistCountLabel.hidden = NO;
			self.deleteSongsLabel.hidden = YES;
		}
		else
		{
			self.deleteSongsLabel.text = @"Clear Playlist";
		}
	}
	else if ([viewObjectsS.multiDeleteList count] == 1)
	{
		self.deleteSongsLabel.text = @"Remove 1 Song  ";
	}
	else 
	{
		self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
	}
}

- (void) showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}

- (void)savePlaylistAction:(id)sender
{
	if (self.deleteSongsLabel.hidden == YES)
	{
		if (!self.tableView.editing)
		{
			if (settingsS.isOfflineMode)
			{
				[self showSavePlaylistAlert];
			}
			else
			{
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																	  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																	 delegate:self 
															cancelButtonTitle:nil
															otherButtonTitles:@"Local", @"Server", nil];
				[myAlertView show];
			}
		}
	}
	else 
	{
		[self unregisterForNotifications];
		
		if ([self.deleteSongsLabel.text isEqualToString:@"Clear Playlist"])
		{
			if (settingsS.isJukeboxEnabled)
			{
				[databaseS resetJukeboxPlaylist];
				[jukeboxS jukeboxClearPlaylist];
			}
			else
			{
                [audioEngineS.player stop];
				[databaseS resetCurrentPlaylistDb];
			}
			
			[self editPlaylistAction:nil];
			
			[self updateCurrentPlaylistCount];
			[self.tableView reloadData];
		}
		else
		{
			//
			// Delete action
			//
			
			[playlistS deleteSongs:viewObjectsS.multiDeleteList];
			
			[self updateCurrentPlaylistCount];
			[self.tableView reloadData];
						
			/*// Create indexPaths from multiDeleteList and delete the rows in the table view
			NSMutableArray *indexes = [[NSMutableArray alloc] init];
			for (NSNumber *index in viewObjectsS.multiDeleteList)
			{
				@autoreleasepool 
				{
					[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
				}
			}
			
			@try
			{
				[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:NO];
			}
			@catch (NSException *exception) 
			{
			//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
			}*/
			
			[self editPlaylistAction:nil];
		}
		
		// Fix the playlist count
		NSUInteger songCount = playlistS.count;
		if (songCount == 1)
			self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
		else
			self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)songCount];
		
		if (!settingsS.isJukeboxEnabled)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
		
		[self registerForNotifications];
	}
}

- (void)uploadPlaylist:(NSString*)name
{	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
	NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
	NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
	NSString *table = playlistS.isShuffle ? shufTable : currTable;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	 {
		 for (int i = 0; i < self.currentPlaylistCount; i++)
		 {
			 @autoreleasepool 
			 {
				 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
				 [songIds addObject:n2N(aSong.songId)];
			 }
		 }
	 }];
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
	self.request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
	
	self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

- (void)showSavePlaylistAlert
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	[myAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Local or Server?"])
	{
		if (buttonIndex == 0)
		{
			self.savePlaylistLocal = YES;
		}
		else if (buttonIndex == 1)
		{
			self.savePlaylistLocal = NO;
		}
		else if (buttonIndex == 2)
		{
			return;
		}
		
		[self showSavePlaylistAlert];
	}
    else if([alertView.title isEqualToString:@"Playlist Name:"])
	{
        NSString *text = [alertView textFieldAtIndex:0].text;
		if(buttonIndex == 1)
		{
			if (self.savePlaylistLocal || settingsS.isOfflineMode)
			{
				// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
				NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", [text md5]];
				if (!test)
				{
					NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
					NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
					NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
					NSString *table = playlistS.isShuffle ? shufTable : currTable;
					
					[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", text, [text md5]];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
						
						[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
						if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
						[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
					}];
				}
				else
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				}
			}
			else
			{
				NSString *tableName = [NSString stringWithFormat:@"splaylist%@", [text md5]];
				if ([databaseS.localPlaylistsDbQueue tableExists:tableName])
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				}
				else 
				{
					[self uploadPlaylist:text];
				}
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
        NSString *text = [alertView ex2CustomObjectForKey:@"name"];
		if(buttonIndex == 1)
		{
			// If yes, overwrite the playlist
			if (self.savePlaylistLocal || settingsS.isOfflineMode)
			{
				NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [text md5]]];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
					
					[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
					if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
					if (playlistS.isShuffle)
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [text md5]]];
					else
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [text md5]]];
					[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
				}];
			}
			else
			{
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", [text md5]]];
				}];
				
				[self uploadPlaylist:text];
			}
		}
	}
	
	self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
	self.playlistCountLabel.backgroundColor = [UIColor clearColor];
}

- (void)selectRow
{
	[self.tableView reloadData];
	if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
	{
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	}
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    /*// Return the number of rows in the section.
	if (settingsS.isPlaylistUnlocked)
	{
		if (settingsS.isJukeboxEnabled)
			currentPlaylistCount = [databaseS.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
		else
			currentPlaylistCount = [databaseS.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
	}
	else
	{
		currentPlaylistCount = 0;
	}*/
	
	return self.currentPlaylistCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *cellIdentifier = @"CurrentPlaylistSongSmallCell";
    CurrentPlaylistSongSmallUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) 
	{
        cell = [[CurrentPlaylistSongSmallUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	
    cell.indexPath = indexPath;
	
	cell.deleteToggleImage.hidden = !self.tableView.editing;
	cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	if ([viewObjectsS.multiDeleteList containsObject:@(indexPath.row)])
	{
		cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	ISMSSong *aSong;
	if (settingsS.isJukeboxEnabled)
	{
		if (playlistS.isShuffle)
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
		else
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
	}
	else
	{
		if (playlistS.isShuffle)
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
		else
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
	}
	
	if (indexPath.row == playlistS.currentIndex && (audioEngineS.player.isStarted || (settingsS.isJukeboxEnabled && jukeboxS.jukeboxIsPlaying)))
	{
		cell.numberLabel.hidden = YES;
		cell.nowPlayingImageView.hidden = NO;
	}
	else
	{
		cell.numberLabel.hidden = NO;
		cell.nowPlayingImageView.hidden = YES;
		cell.numberLabel.text = [NSString stringWithFormat:@"%li", (long)(indexPath.row + 1)];
	}
	
	cell.songNameLabel.text = aSong.title;

	if (aSong.album)
		cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
	else
		cell.artistNameLabel.text = aSong.artist;

	cell.durationLabel.text = [NSString formatTime:[aSong.duration floatValue]];	
	
	// Hide the duration labels if editing
	if (self.tableView.editing)
	{
		cell.durationLabel.hidden = YES;
	}
	
    return cell;
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


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	NSInteger fromRow = fromIndexPath.row + 1;
	NSInteger toRow = toIndexPath.row + 1;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	 {
		 NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		 NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		 NSString *table = playlistS.isShuffle ? shufTable : currTable;
		 		 
		 [db executeUpdate:@"DROP TABLE moveTemp"];
		 NSString *query = [NSString stringWithFormat:@"CREATE TABLE moveTemp (%@)", [ISMSSong standardSongColumnSchema]];
		 [db executeUpdate:query];
		 
		 if (fromRow < toRow)
		 {
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ? AND ROWID <= ?", table], @(fromRow), @(toRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(toRow)];
			 
			 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
			 [db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
		 }
		 else
		 {
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(toRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID >= ? AND ROWID < ?", table], @(toRow), @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(fromRow)];
			 
			 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
			 [db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
		 }
	 }];
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxReplacePlaylistWithLocal];
	}
		
	// Fix the multiDeleteList to reflect the new row positions
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
						[tempMultiDeleteList addObject:@(toIndexPath.row)];
					}
					else 
					{
						newPosition = [position intValue] + 1;
						[tempMultiDeleteList addObject:@(newPosition)];
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
						[tempMultiDeleteList addObject:@(toIndexPath.row)];
					}
					else 
					{
						newPosition = [position intValue] - 1;
						[tempMultiDeleteList addObject:@(newPosition)];
					}
				}
				else
				{
					[tempMultiDeleteList addObject:position];
				}
			}
		}
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
	}
	
	// Correct the value of currentPlaylistPosition
	if (fromIndexPath.row == playlistS.currentIndex)
	{
		playlistS.currentIndex = toIndexPath.row;
	}
	else 
	{
		if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex)
		{
			playlistS.currentIndex = playlistS.currentIndex - 1;
		}
		else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex)
		{
			playlistS.currentIndex = playlistS.currentIndex + 1;
		}
	}
	
	if (!settingsS.isJukeboxEnabled)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}



#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	[musicS playSongAtPosition:indexPath.row];
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", 
			   (long)[error code],
			   [error localizedDescription]];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	self.connection = nil;
	self.receivedData = nil;
}	

- (NSURLRequest *)connection: (NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) 
	{
        NSMutableURLRequest *newRequest = [self.request mutableCopy];
        [newRequest setURL:[inRequest URL]];
        return newRequest;
    } 
	else 
	{
        return inRequest;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	[self parseData];
	
	self.tableView.scrollEnabled = YES;
	self.connection = nil;
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
}

- (void)parseData
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self subsonicErrorCode:nil message:error.description];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:code message:message];
        }
    }
	
	self.receivedData = nil;
	
	[viewObjectsS hideLoadingScreen];
}


@end

