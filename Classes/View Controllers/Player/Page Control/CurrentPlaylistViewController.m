//
//  CurrentPlaylistViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistViewController.h"
#import "CustomUIAlertView.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "NSError+ISMSError.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "SUSLoader.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation CurrentPlaylistViewController

#pragma mark View lifecycle

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerForNotifications {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxSongInfo) name:ISMSNotification_JukeboxSongInfo object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
}

- (void)unregisterForNotifications {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
		
    self.tableView.backgroundColor = UIColor.systemBackgroundColor;
	
    [self registerForNotifications];
				
    // Setup header view
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    self.headerView.backgroundColor = UIColor.systemBackgroundColor;//[UIColor colorWithWhite:.3 alpha:1];
    
    self.savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 232, 34)];
    self.savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
    self.savePlaylistLabel.textColor = UIColor.labelColor;//[UIColor whiteColor];
    self.savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
    self.savePlaylistLabel.font = [UIFont boldSystemFontOfSize:22];// ISMSBoldFont(22);
    self.savePlaylistLabel.text = @"Save Playlist";
    [self.headerView addSubview:self.savePlaylistLabel];
    
    self.playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 33, 232, 14)];
    self.playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.playlistCountLabel.backgroundColor = [UIColor clearColor];
    self.playlistCountLabel.textColor = UIColor.labelColor;//[UIColor whiteColor];
    self.playlistCountLabel.textAlignment = NSTextAlignmentCenter;
    self.playlistCountLabel.font = [UIFont boldSystemFontOfSize:12];//ISMSBoldFont(12);
    [self.headerView addSubview:self.playlistCountLabel];
    
    self.savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.savePlaylistButton.frame = CGRectMake(0, 0, 232, 40);
    [self.savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.savePlaylistButton];
    
    self.editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(232, 0, 88, 50)];
    self.editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
    self.editPlaylistLabel.textColor = UIColor.labelColor;//[UIColor whiteColor];
    self.editPlaylistLabel.textAlignment = NSTextAlignmentCenter;
    self.editPlaylistLabel.font = [UIFont boldSystemFontOfSize:22];//ISMSBoldFont(22);
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
    self.deleteSongsLabel.textColor = UIColor.labelColor;//[UIColor whiteColor];
    self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
    self.deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];//ISMSBoldFont(22);
    self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
    self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
    self.deleteSongsLabel.text = @"Remove # Songs";
    self.deleteSongsLabel.hidden = YES;
    [self.headerView addSubview:self.deleteSongsLabel];
    
    [self.view addSubview:self.headerView];
    self.headerView.width = self.view.width;
    [self updateCurrentPlaylistCount];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, self.headerView.height, self.view.width, self.view.height - self.headerView.height)];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    self.tableView.rowHeight = 60;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideEditControls) name:@"hideEditControls" object:nil];
	
	[self.tableView reloadData];
    
    [self selectRow];
}

- (void)showStore {
	[NSNotificationCenter postNotificationToMainThreadWithName:@"player show store"];
}

- (void)viewWillAppear:(BOOL)animated  {
	[super viewWillAppear:animated];
	
	[self selectRow];
}

- (void)viewWillDisappear:(BOOL)animated  {
    [super viewWillDisappear:animated];
	
	[self unregisterForNotifications];

	if (self.isEditing) {
        [self setEditing:NO animated:YES];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideEditControls" object:nil];
	
	self.headerView = nil;
}

- (void)jukeboxSongInfo {
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
	[self selectRow];
}

- (void)songsQueued {
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
}

- (void)updateCurrentPlaylistCount {
	self.currentPlaylistCount = [playlistS count];
		
    if (self.currentPlaylistCount == 1) {
		self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
    } else {
		self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
    }
}

- (void)editPlaylistAction:(id)sender {
	if (!self.isEditing) {
        // Deelect all the rows
        for (int i = 0; i < self.currentPlaylistCount; i++) {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO];
        }
        
		[self setEditing:YES animated:YES];
		self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
		self.editPlaylistLabel.text = @"Done";
        
		[self showDeleteButton];
	} else {
		[self setEditing:NO animated:YES];
		[self hideDeleteButton];
		self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
		self.editPlaylistLabel.text = @"Edit";
		
		// Reload the table to correct the numbers
//		[self.tableView reloadData];

		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

- (void)hideEditControls {
    if (self.isEditing) {
		[self editPlaylistAction:nil];
    }
}

- (void)showDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
		self.deleteSongsLabel.text = @"Clear Playlist";
	} else if (selectedRowsCount == 1) {
		self.deleteSongsLabel.text = @"Remove 1 Song  ";
	} else {
		self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)selectedRowsCount];
	}
	
	self.savePlaylistLabel.hidden = YES;
	self.playlistCountLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}

- (void)hideDeleteButton {
    if (!self.isEditing) {
        self.savePlaylistLabel.hidden = NO;
        self.playlistCountLabel.hidden = NO;
        self.deleteSongsLabel.hidden = YES;
        return;
    }
    
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (selectedRowsCount == 0) {
        self.deleteSongsLabel.text = @"Clear Playlist";
	} else if (selectedRowsCount == 1) {
		self.deleteSongsLabel.text = @"Remove 1 Song  ";
	} else {
		self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)selectedRowsCount];
	}
}

- (NSMutableArray<NSNumber*> *)selectedRowIndexes {
    NSMutableArray<NSNumber*> *selectedRowIndexes = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        [selectedRowIndexes addObject:@(indexPath.row)];
    }
    return selectedRowIndexes;
}

- (void)savePlaylistAction:(id)sender {
	if (self.deleteSongsLabel.hidden == YES) {
		if (!self.isEditing) {
			if (settingsS.isOfflineMode) {
				[self showSavePlaylistAlert];
			} else {
				UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																	  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																	 delegate:self 
															cancelButtonTitle:nil
															otherButtonTitles:@"Local", @"Server", nil];
				[myAlertView show];
			}
		}
	} else {
        NSMutableArray *selectedRowIndexes = [self selectedRowIndexes];
        
		[self unregisterForNotifications];
		
        if (selectedRowIndexes.count == 0) {
            // Select all the rows
            for (int i = 0; i < self.currentPlaylistCount; i++) {
                [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
            [self showDeleteButton];
		} else {
			// Delete action
            [playlistS deleteSongs:selectedRowIndexes];
			[self updateCurrentPlaylistCount];
            [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationAutomatic];
            [self updateTableCellNumbers];
            
//			[self.tableView reloadData];
			[self editPlaylistAction:nil];
		}
		
		// Fix the playlist count
		NSUInteger songCount = playlistS.count;
        if (songCount == 1) {
			self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
        } else {
			self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)songCount];
        }
        
        if (!settingsS.isJukeboxEnabled) {
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
        }
        
		[self registerForNotifications];
	}
}

- (void)uploadPlaylist:(NSString*)name {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
	NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
	NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
	NSString *table = playlistS.isShuffle ? shufTable : currTable;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		 for (int i = 0; i < self.currentPlaylistCount; i++) {
			 @autoreleasepool {
				 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
				 [songIds addObject:n2N(aSong.songId)];
			 }
		 }
	 }];
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [EX2Dispatch runInMainThreadAsync:^{
            if (error) {
                NSString *message = @"";
                message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@",
                           (long)[error code],
                           [error localizedDescription]];
                
                // Inform the user that the connection failed.
                CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                
                self.tableView.scrollEnabled = YES;
                [viewObjectsS hideLoadingScreen];
            } else {
                RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
                if (!root.isValid) {
                    NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
                    [self subsonicErrorCode:nil message:error.description];
                } else {
                    RXMLElement *error = [root child:@"error"];
                    if (error.isValid)
                    {
                        NSString *code = [error attribute:@"code"];
                        NSString *message = [error attribute:@"message"];
                        [self subsonicErrorCode:code message:message];
                    }
                }
                
                self.tableView.scrollEnabled = YES;
                [viewObjectsS hideLoadingScreen];
            }
        }];
    }];
    [dataTask resume];
    
    self.tableView.scrollEnabled = NO;
    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
    alert.tag = 1;
    [alert show];
}

- (void)showSavePlaylistAlert
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	[myAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([alertView.title isEqualToString:@"Local or Server?"]) {
		if (buttonIndex == 0) {
			self.savePlaylistLocal = YES;
		} else if (buttonIndex == 1) {
			self.savePlaylistLocal = NO;
		} else if (buttonIndex == 2) {
			return;
		}
		
		[self showSavePlaylistAlert];
	} else if ([alertView.title isEqualToString:@"Playlist Name:"]) {
        NSString *text = [alertView textFieldAtIndex:0].text;
		if (buttonIndex == 1) {
			if (self.savePlaylistLocal || settingsS.isOfflineMode) {
				// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
				NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", [text md5]];
				if (!test) {
					NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
					NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
					NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
					NSString *table = playlistS.isShuffle ? shufTable : currTable;
					
					[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
						[db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", text, [text md5]];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
						
						[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
						if ([db hadError]) { DDLogError(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
						[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
					}];
				} else {
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				}
			} else {
				NSString *tableName = [NSString stringWithFormat:@"splaylist%@", [text md5]];
				if ([databaseS.localPlaylistsDbQueue tableExists:tableName]) {
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				} else {
					[self uploadPlaylist:text];
				}
			}
		}
	} else if([alertView.title isEqualToString:@"Overwrite?"]) {
        NSString *text = [alertView ex2CustomObjectForKey:@"name"];
		if (buttonIndex == 1) {
			// If yes, overwrite the playlist
			if (self.savePlaylistLocal || settingsS.isOfflineMode) {
				NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [text md5]]];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
					
					[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
					if ([db hadError]) { DDLogError(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
                    if (playlistS.isShuffle) {
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM shufflePlaylist", [text md5]]];
                    } else {
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM currentPlaylist", [text md5]]];
                    }
                    [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
				}];
			} else {
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", [text md5]]];
				}];
				
				[self uploadPlaylist:text];
			}
		}
	}
	
	self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
	self.playlistCountLabel.backgroundColor = [UIColor clearColor];
}

- (void)selectRow {
	[self.tableView reloadData];
	if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	}
}

#pragma mark Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.currentPlaylistCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
	
	ISMSSong *aSong;
	if (settingsS.isJukeboxEnabled) {
        if (playlistS.isShuffle) {
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
        } else {
            aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
        }
	} else {
        if (playlistS.isShuffle) {
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
        } else {
			aSong = [ISMSSong songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
        }
	}
    
    cell.autoScroll = NO;
    cell.hideCoverArt = YES;
    cell.number = indexPath.row + 1;
    [cell updateWithModel:aSong];
	
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
	NSInteger fromRow = fromIndexPath.row + 1;
	NSInteger toRow = toIndexPath.row + 1;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		 NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		 NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		 NSString *table = playlistS.isShuffle ? shufTable : currTable;
		 		 
		 [db executeUpdate:@"DROP TABLE moveTemp"];
		 NSString *query = [NSString stringWithFormat:@"CREATE TABLE moveTemp (%@)", [ISMSSong standardSongColumnSchema]];
		 [db executeUpdate:query];
		 
		 if (fromRow < toRow) {
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ? AND ROWID <= ?", table], @(fromRow), @(toRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(toRow)];
			 
			 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
			 [db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
		 } else {
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(toRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID >= ? AND ROWID < ?", table], @(toRow), @(fromRow)];
			 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(fromRow)];
			 
			 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
			 [db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
		 }
	 }];
	
	if (settingsS.isJukeboxEnabled) {
		[jukeboxS replacePlaylistWithLocal];
	}
	
	// Correct the value of currentPlaylistPosition
	if (fromIndexPath.row == playlistS.currentIndex) {
		playlistS.currentIndex = toIndexPath.row;
	} else {
		if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex) {
			playlistS.currentIndex = playlistS.currentIndex - 1;
		} else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex) {
			playlistS.currentIndex = playlistS.currentIndex + 1;
		}
	}
	
    if (!settingsS.isJukeboxEnabled) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
    
    if (self.isEditing) {
        [self showDeleteButton];
        return;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];

    [EX2Dispatch runInMainThreadAfterDelay:0.5 block:^{
        [musicS playSongAtPosition:indexPath.row];
    }];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    
    if (self.isEditing) {
        [self hideDeleteButton];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISMSSong *song = [playlistS songForIndex:indexPath.row];
    if (!song.isVideo) {
        return [SwipeAction downloadQueueAndDeleteConfigWithModel:song deleteHandler:^{
            [playlistS deleteSongs:@[@(indexPath.row)]];
            [self updateCurrentPlaylistCount];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
    }
    return nil;
}

- (void)updateTableCellNumbers {
    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        UniversalTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.number = indexPath.row + 1;
    }
}

@end
