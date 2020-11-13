//
//  BookmarksViewController.m
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BookmarksViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation BookmarksViewController

#pragma mark - View lifecycle

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
		
	self.isNoBookmarksScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Bookmarks";
	
	if (settingsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsAction:)];
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.rowHeight = 80;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
	    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
	
	self.tableView.tableHeaderView = nil;
	
	if (self.isNoBookmarksScreenShowing == YES) {
		[self.noBookmarksScreen removeFromSuperview];
		self.isNoBookmarksScreenShowing = NO;
	}
	
	NSUInteger bookmarksCount = [databaseS.bookmarksDbQueue intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
	if (bookmarksCount == 0) {
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
		
	} else {
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

- (void)viewWillDisappear:(BOOL)animated {
	self.bookmarkIds = nil;
}

- (void)loadBookmarkIds {
	NSMutableArray *bookmarkIdsTemp = [[NSMutableArray alloc] initWithCapacity:0];
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:@"SELECT bookmarkId FROM bookmarks"];
		while ([result next]) {
			@autoreleasepool {
				NSNumber *bookmarkId = [result objectForColumnIndex:0];
				if (bookmarkId) [bookmarkIdsTemp addObject:bookmarkId];
			}
		}
		[result close];
	}];
	self.bookmarkIds = bookmarkIdsTemp;
}

- (void)showDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
		self.deleteBookmarksLabel.text = @"Clear Bookmarks";
	} else if (selectedRowsCount == 1) {
		self.deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	} else {
		self.deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %lu Bookmarks", (unsigned long)selectedRowsCount];
	}
	
	self.bookmarkCountLabel.hidden = YES;
	self.deleteBookmarksLabel.hidden = NO;
}


- (void)hideDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
		if (!self.isEditing) {
			self.bookmarkCountLabel.hidden = NO;
			self.deleteBookmarksLabel.hidden = YES;
		} else {
			self.deleteBookmarksLabel.text = @"Clear Bookmarks";
		}
	} else if (selectedRowsCount == 1) {
		self.deleteBookmarksLabel.text = @"Remove 1 Bookmark";
	} else {
		self.deleteBookmarksLabel.text = [NSString stringWithFormat:@"Remove %lu Bookmarks", (unsigned long)selectedRowsCount];
	}
}

- (void)editBookmarksAction:(id)sender {
	if (self.isEditing == NO) {
		[self.tableView reloadData];
        self.editing = YES;
		self.editBookmarksLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		self.editBookmarksLabel.text = @"Done";
		[self showDeleteButton];
    } else {
		[self hideDeleteButton];
        self.editing = NO;
		self.editBookmarksLabel.backgroundColor = [UIColor clearColor];
		self.editBookmarksLabel.text = @"Edit";
		
		// Reload the table
		//[self.tableView reloadData];
		[self viewWillAppear:NO];
	}
}

- (void)deleteBookmarksAction:(id)sender {
	if ([self.deleteBookmarksLabel.text isEqualToString:@"Clear Bookmarks"]) {
        // Select all the rows
        for (int i = 0; i < self.bookmarkIds.count; i++) {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        [self showDeleteButton];
	} else {
        // Sort the row indexes to make sure they're accending
        NSMutableArray<NSNumber*> *selectedIndexes = self.selectedRowIndexes;
        [selectedIndexes sortUsingSelector:@selector(compare:)];
        
		for (NSNumber *index in selectedIndexes) {
			NSNumber *bookmarkId = [self.bookmarkIds objectAtIndex:[index intValue]];
			[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
				 [db executeUpdate:@"DELETE FROM bookmarks WHERE bookmarkId = ?", bookmarkId];
			}];
		}
        
        for (NSNumber *index in self.selectedRowIndexes.reverseObjectEnumerator) {
            [self.bookmarkIds removeObjectAtIndex:[index integerValue]];
        }
		
		@try {
            [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationRight];
		} @catch (NSException *exception) {
            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
		
		[self editBookmarksAction:nil];
	}
}

- (void)settingsAction:(id)sender {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender {
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark Table View

- (NSMutableArray<NSNumber*> *)selectedRowIndexes {
    NSMutableArray<NSNumber*> *selectedRowIndexes = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        [selectedRowIndexes addObject:@(indexPath.row)];
    }
    return selectedRowIndexes;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.bookmarkIds.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __block ISMSSong *song;
    __block NSString *name = nil;
    __block int position = 0;
    [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
        song = [ISMSSong songFromDbResult:result];
        name = [result stringForColumn:@"name"];
        position = [result intForColumn:@"position"];
        [result close];
    }];
    
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideHeaderLabel = NO;
    cell.hideNumberLabel = YES;
    cell.headerText = [NSString stringWithFormat:@"%@ - %@", name, [NSString formatTime:(float)position]];
    [cell updateWithModel:song];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
    
    if (self.isEditing) {
        [self showDeleteButton];
        return;
    }
	
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	playlistS.isShuffle = NO;
	
	__block NSUInteger bookmarkId = 0;
	__block NSUInteger playlistIndex = 0;
	__block NSUInteger offsetSeconds = 0;
	__block NSUInteger offsetBytes = 0;
	__block ISMSSong *aSong;
	
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
		aSong = [ISMSSong songFromDbResult:result];
		bookmarkId = [result intForColumn:@"bookmarkId"];
		playlistIndex = [result intForColumn:@"playlistIndex"];
		offsetSeconds = [result intForColumn:@"position"];
		offsetBytes = [result intForColumn:@"bytes"];
		[result close];
	}];
		
	// See if there's a playlist table for this bookmark
	if ([databaseS.bookmarksDbQueue tableExists:[NSString stringWithFormat:@"bookmark%lu", (unsigned long)bookmarkId]]) {
		// Save the playlist
		NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
		NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		NSString *table = playlistS.isShuffle ? shufTable : currTable;
		
		[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
			[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylistDb.%@ SELECT * FROM bookmark%lu", table, (unsigned long)bookmarkId]];
			[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
		}];
		
        if (settingsS.isJukeboxEnabled) {
			[jukeboxS jukeboxReplacePlaylistWithLocal];
        }
	} else {
		[aSong addToCurrentPlaylistDbQueue];
	}
	
	playlistS.currentIndex = playlistIndex;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
		
	[self showPlayer];
	
	// Check if these are old bookmarks and don't have byteOffset saved
	if (offsetBytes == 0 && offsetSeconds != 0) {
		// By default, use the server reported bitrate
		NSUInteger bitrate = [aSong.bitRate intValue];
		
		if (aSong.transcodedSuffix) {
			// This is a transcode, guess the bitrate and byteoffset
			NSUInteger maxBitrate = settingsS.currentMaxBitrate == 0 ? 128 : settingsS.currentMaxBitrate;
			bitrate = maxBitrate < [aSong.bitRate intValue] ? maxBitrate : [aSong.bitRate intValue];
		}

		// Use the bitrate to get byteoffset
		offsetBytes = BytesForSecondsAtBitrate(offsetSeconds, bitrate);
	}
	
    if (settingsS.isJukeboxEnabled) {
		[musicS playSongAtPosition:playlistIndex];
    } else {
		[musicS startSongAtOffsetInBytes:offsetBytes andSeconds:offsetSeconds];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    
    if (self.isEditing) {
        [self hideDeleteButton];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __block ISMSSong *song = nil;
    [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
        song = [ISMSSong songFromDbResult:result];
        [result close];
    }];
    return [SwipeAction downloadQueueAndDeleteConfigWithModel:song deleteHandler:^{
        [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
             [db executeUpdate:@"DELETE FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndex:indexPath.row]];
        }];
        
        [self.bookmarkIds removeObjectAtIndex:indexPath.row];
        
        @try {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
        } @catch (NSException *exception) {
            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
        }
    }];
}

/*// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    // Move the bookmark
    NSInteger fromRow = fromIndexPath.row + 1;
    NSInteger toRow = toIndexPath.row + 1;
    
    [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
    [databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
        
    if (fromRow < toRow) {
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
        
        [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
    } else {
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
        
        [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
    }
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}*/


@end

