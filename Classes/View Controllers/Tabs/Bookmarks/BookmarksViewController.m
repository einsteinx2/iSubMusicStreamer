//
//  BookmarksViewController.m
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BookmarksViewController.h"
#import "ServerListViewController.h"
#import "Defines.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation BookmarksViewController

#pragma mark - View lifecycle

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
		
	self.isNoBookmarksScreenShowing = NO;
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    self.tableViewTopConstraint = [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor];
    [NSLayoutConstraint activateConstraints:@[
        self.tableViewTopConstraint,
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
		
	self.title = @"Bookmarks";
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.rowHeight = Defines.tallRowHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
	    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
    [self addShowPlayerButton];
	
	self.tableView.tableHeaderView = nil;
	
	if (self.isNoBookmarksScreenShowing == YES) {
		[self.noBookmarksScreen removeFromSuperview];
		self.isNoBookmarksScreenShowing = NO;
	}
	
    // TODO: implement this
//	NSUInteger bookmarksCount = [databaseS.bookmarksDbQueue intForQuery:@"SELECT COUNT(*) FROM bookmarks"];
//	if (bookmarksCount == 0) {
//        [self removeSaveEditButtons];
//
//		self.isNoBookmarksScreenShowing = YES;
//		self.noBookmarksScreen = [[UIImageView alloc] init];
//		self.noBookmarksScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
//		self.noBookmarksScreen.frame = CGRectMake(40, 100, 240, 180);
//		self.noBookmarksScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
//		self.noBookmarksScreen.image = [UIImage imageNamed:@"loading-screen-image"];
//		self.noBookmarksScreen.alpha = .80;
//
//		UILabel *textLabel = [[UILabel alloc] init];
//		textLabel.backgroundColor = [UIColor clearColor];
//		textLabel.textColor = [UIColor whiteColor];
//		textLabel.font = [UIFont boldSystemFontOfSize:30];
//		textLabel.textAlignment = NSTextAlignmentCenter;
//		textLabel.numberOfLines = 0;
//		if (settingsS.isOfflineMode) {
//			[textLabel setText:@"No Offline\nBookmarks"];
//		}
//		else {
//			[textLabel setText:@"No Saved\nBookmarks"];
//		}
//		textLabel.frame = CGRectMake(20, 20, 200, 140);
//		[self.noBookmarksScreen addSubview:textLabel];
//
//		[self.view addSubview:self.noBookmarksScreen];
//
//	} else {
//        [self addSaveEditButtons:bookmarksCount];
//	}
	
	[self loadBookmarkIds];
	
	[self.tableView reloadData];
	
	[Flurry logEvent:@"BookmarksTab"];
}

- (void)removeSaveEditButtons {
    if (!self.isSaveEditShowing) return;
    
    self.isSaveEditShowing = NO;
    [self.saveEditContainer removeFromSuperview]; self.saveEditContainer = nil;
    [self.bookmarkCountLabel removeFromSuperview]; self.bookmarkCountLabel = nil;
    [self.deleteBookmarksButton removeFromSuperview]; self.deleteBookmarksButton = nil;
    [self.editBookmarksLabel removeFromSuperview]; self.editBookmarksLabel = nil;
    [self.editBookmarksButton removeFromSuperview]; self.editBookmarksButton = nil;
    [self.deleteBookmarksLabel removeFromSuperview]; self.deleteBookmarksLabel = nil;
    
    self.tableViewTopConstraint.constant = 0.0;
    [self.tableView setNeedsUpdateConstraints];
}

- (void)addSaveEditButtons:(NSUInteger)bookmarksCount {
    [self removeSaveEditButtons];
    
    self.isSaveEditShowing = YES;
    
    self.saveEditContainer = [[UIView alloc] init];
    self.saveEditContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.saveEditContainer];
        
    self.bookmarkCountLabel = [[UILabel alloc] init];
    self.bookmarkCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bookmarkCountLabel.textColor = UIColor.labelColor;
    self.bookmarkCountLabel.textAlignment = NSTextAlignmentCenter;
    self.bookmarkCountLabel.font = [UIFont boldSystemFontOfSize:22];
    if (bookmarksCount == 1)
        self.bookmarkCountLabel.text = [NSString stringWithFormat:@"1 Bookmark"];
    else
        self.bookmarkCountLabel.text = [NSString stringWithFormat:@"%lu Bookmarks", (unsigned long)bookmarksCount];
    [self.saveEditContainer addSubview:self.bookmarkCountLabel];
    
    self.deleteBookmarksLabel = [[UILabel alloc] init];
    self.deleteBookmarksLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteBookmarksLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
    self.deleteBookmarksLabel.textColor = UIColor.labelColor;
    self.deleteBookmarksLabel.textAlignment = NSTextAlignmentCenter;
    self.deleteBookmarksLabel.font = [UIFont boldSystemFontOfSize:22];
    self.deleteBookmarksLabel.adjustsFontSizeToFitWidth = YES;
    self.deleteBookmarksLabel.minimumScaleFactor = 12.0 / self.deleteBookmarksLabel.font.pointSize;
    self.deleteBookmarksLabel.text = @"Remove # Bookmarks";
    self.deleteBookmarksLabel.hidden = YES;
    [self.saveEditContainer addSubview:self.deleteBookmarksLabel];
    
    self.deleteBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.deleteBookmarksButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deleteBookmarksButton addTarget:self action:@selector(deleteBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.deleteBookmarksButton];
    
    self.editBookmarksLabel = [[UILabel alloc] init];
    self.editBookmarksLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.editBookmarksLabel.textColor = UIColor.systemBlueColor;
    self.editBookmarksLabel.textAlignment = NSTextAlignmentCenter;
    self.editBookmarksLabel.font = [UIFont boldSystemFontOfSize:22];
    self.editBookmarksLabel.text = @"Edit";
    [self.saveEditContainer addSubview:self.editBookmarksLabel];
    
    self.editBookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editBookmarksButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.editBookmarksButton addTarget:self action:@selector(editBookmarksAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.editBookmarksButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.saveEditContainer.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.saveEditContainer.heightAnchor constraintEqualToConstant:50],
        [self.saveEditContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        
        [self.bookmarkCountLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.bookmarkCountLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.bookmarkCountLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.bookmarkCountLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.deleteBookmarksLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.deleteBookmarksLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.deleteBookmarksLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.deleteBookmarksLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.deleteBookmarksButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.deleteBookmarksButton.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.deleteBookmarksButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.deleteBookmarksButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editBookmarksLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editBookmarksLabel.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editBookmarksLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editBookmarksLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editBookmarksButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editBookmarksButton.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editBookmarksButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editBookmarksButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
    ]];
    
    self.tableViewTopConstraint.constant = 50;
    [self.tableView setNeedsUpdateConstraints];
}

- (void)viewWillDisappear:(BOOL)animated {
	self.bookmarkIds = nil;
}

- (void)loadBookmarkIds {
    // TODO: implement this
//	NSMutableArray *bookmarkIdsTemp = [[NSMutableArray alloc] initWithCapacity:0];
//	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//		FMResultSet *result = [db executeQuery:@"SELECT bookmarkId FROM bookmarks"];
//		while ([result next]) {
//			@autoreleasepool {
//				NSNumber *bookmarkId = [result objectForColumnIndex:0];
//				if (bookmarkId) [bookmarkIdsTemp addObject:bookmarkId];
//			}
//		}
//		[result close];
//	}];
//	self.bookmarkIds = bookmarkIdsTemp;
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
        [self setEditing:YES animated:YES];
		self.editBookmarksLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
        self.editBookmarksLabel.textColor = UIColor.labelColor;
		self.editBookmarksLabel.text = @"Done";
		[self showDeleteButton];
    } else {
        [self setEditing:NO animated:YES];
		[self hideDeleteButton];
        self.editBookmarksLabel.backgroundColor = UIColor.clearColor;
        self.editBookmarksLabel.textColor = UIColor.systemBlueColor;
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
        // TODO: implement this
//        // Sort the row indexes to make sure they're accending
//        NSMutableArray<NSNumber*> *selectedIndexes = self.selectedRowIndexes;
//        [selectedIndexes sortUsingSelector:@selector(compare:)];
//
//		for (NSNumber *index in selectedIndexes) {
//			NSNumber *bookmarkId = [self.bookmarkIds objectAtIndex:[index intValue]];
//			[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//                [db executeUpdate:@"DELETE FROM bookmarks WHERE bookmarkId = ?", bookmarkId];
//                // TODO: Delete the bookmark playlist table as well
//			}];
//		}
//
//        for (NSNumber *index in self.selectedRowIndexes.reverseObjectEnumerator) {
//            [self.bookmarkIds removeObjectAtIndex:[index integerValue]];
//        }
//
//		@try {
//            [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationRight];
//		} @catch (NSException *exception) {
//            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
//		}
//
//		[self editBookmarksAction:nil];
	}
}

#pragma mark Table View

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

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
//    __block ISMSSong *song;
//    __block NSString *name = nil;
//    __block int position = 0;
//    [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
//        song = [ISMSSong songFromDbResult:result];
//        name = [result stringForColumn:@"name"];
//        position = [result intForColumn:@"position"];
//        [result close];
//    }];
//
//    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
//    cell.hideHeaderLabel = NO;
//    cell.hideNumberLabel = YES;
//    cell.headerText = [NSString stringWithFormat:@"%@ - %@", name, [NSString formatTime:(float)position]];
//    [cell updateWithModel:song];
//    return cell;
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
    
//    if (self.isEditing) {
//        [self showDeleteButton];
//        return;
//    }
//
//	if (settingsS.isJukeboxEnabled) {
//		[databaseS resetJukeboxPlaylist];
//		[jukeboxS clearRemotePlaylist];
//	} else {
//		[databaseS resetCurrentPlaylistDb];
//	}
//	PlayQueue.shared.isShuffle = NO;
//
//	__block NSUInteger bookmarkId = 0;
//	__block NSUInteger playlistIndex = 0;
//	__block NSUInteger offsetSeconds = 0;
//	__block NSUInteger offsetBytes = 0;
//	__block ISMSSong *aSong;
//
//	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//		FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
//		aSong = [ISMSSong songFromDbResult:result];
//		bookmarkId = [result intForColumn:@"bookmarkId"];
//		playlistIndex = [result intForColumn:@"playlistIndex"];
//		offsetSeconds = [result intForColumn:@"position"];
//		offsetBytes = [result intForColumn:@"bytes"];
//		[result close];
//	}];
//
//	// See if there's a playlist table for this bookmark
//	if ([databaseS.bookmarksDbQueue tableExists:[NSString stringWithFormat:@"bookmark%lu", (unsigned long)bookmarkId]]) {
//		// Save the playlist
//		NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
//		NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//		NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
//		NSString *table = PlayQueue.shared.isShuffle ? shufTable : currTable;
//
//		[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//			[db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
//			[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylistDb.%@ SELECT * FROM bookmark%lu", table, (unsigned long)bookmarkId]];
//			[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
//		}];
//
//        if (settingsS.isJukeboxEnabled) {
//			[jukeboxS replacePlaylistWithLocal];
//        }
//	} else {
//		[aSong addToCurrentPlaylistDbQueue];
//	}
//	
//	PlayQueue.shared.currentIndex = playlistIndex;
//	
//	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
//		
//	[self showPlayer];
//	
//	// Check if these are old bookmarks and don't have byteOffset saved
//	if (offsetBytes == 0 && offsetSeconds != 0) {
//		// By default, use the server reported bitrate
//		NSUInteger bitrate = [aSong.bitRate intValue];
//		
//		if (aSong.transcodedSuffix) {
//			// This is a transcode, guess the bitrate and byteoffset
//			NSUInteger maxBitrate = settingsS.currentMaxBitrate == 0 ? 128 : settingsS.currentMaxBitrate;
//			bitrate = maxBitrate < [aSong.bitRate intValue] ? maxBitrate : [aSong.bitRate intValue];
//		}
//
//		// Use the bitrate to get byteoffset
//		offsetBytes = BytesForSecondsAtBitrate(offsetSeconds, bitrate);
//	}
//	
//    if (settingsS.isJukeboxEnabled) {
//		[musicS playSongAtPosition:playlistIndex];
//    } else {
//		[musicS startSongAtOffsetInBytes:offsetBytes andSeconds:offsetSeconds];
//    }
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

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __block ISMSSong *song = nil;
//    [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet *result = [db executeQuery:@"SELECT * FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndexSafe:indexPath.row]];
//        song = [ISMSSong songFromDbResult:result];
//        [result close];
//    }];
//    return [SwipeAction downloadQueueAndDeleteConfigWithModel:song deleteHandler:^{
//        [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//             [db executeUpdate:@"DELETE FROM bookmarks WHERE bookmarkId = ?", [self.bookmarkIds objectAtIndex:indexPath.row]];
//        }];
//
//        [self.bookmarkIds removeObjectAtIndex:indexPath.row];
//
//        @try {
//            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
//        } @catch (NSException *exception) {
//            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
//        }
//    }];
    return nil;
}

/*// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    // Move the bookmark
    NSInteger fromRow = fromIndexPath.row + 1;
    NSInteger toRow = toIndexPath.row + 1;
    
    [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarksTemp"];
    [databaseS.bookmarksDb executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
        
    if (fromRow < toRow) {
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", [NSNumber numberWithInt:fromRow], [NSNumber numberWithInt:toRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:toRow]];
        
        [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
    } else {
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", [NSNumber numberWithInt:toRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", [NSNumber numberWithInt:toRow], [NSNumber numberWithInt:fromRow]];
        [databaseS.bookmarksDb executeUpdate:@"INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", [NSNumber numberWithInt:fromRow]];
        
        [databaseS.bookmarksDb executeUpdate:@"DROP TABLE bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
        [databaseS.bookmarksDb executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
    }
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}*/


@end

