//
//  CurrentPlaylistViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistViewController.h"
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
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)registerForNotifications {
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_BassFreed];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxSongInfo) name:ISMSNotification_JukeboxSongInfo];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount"];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued];
}

- (void)unregisterForNotifications {
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_BassInitialized];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_BassFreed];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CurrentPlaylistShuffleToggled];
	[NSNotificationCenter removeObserverOnMainThread:self name:@"updateCurrentPlaylistCount"];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CurrentPlaylistSongsQueued];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_JukeboxSongInfo];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    self.title = @"Play Queue";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismiss:)];
    UINavigationBarAppearance* appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    self.navigationItem.compactAppearance = appearance;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;

    [self registerForNotifications];
				
    // Setup header view
    self.saveEditContainer = [[UIView alloc] init];
    self.saveEditContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.saveEditContainer];
    
    self.savePlaylistLabel = [[UILabel alloc] init];
    self.savePlaylistLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.savePlaylistLabel.textColor = UIColor.labelColor;
    self.savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
    self.savePlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
    self.savePlaylistLabel.text = @"Save Playlist";
    [self.saveEditContainer addSubview:self.savePlaylistLabel];
    
    self.playlistCountLabel = [[UILabel alloc] init];
    self.playlistCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.playlistCountLabel.textColor = UIColor.labelColor;
    self.playlistCountLabel.textAlignment = NSTextAlignmentCenter;
    self.playlistCountLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.saveEditContainer addSubview:self.playlistCountLabel];
    [self updateCurrentPlaylistCount];
    
    self.deleteSongsLabel = [[UILabel alloc] init];
    self.deleteSongsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
    self.deleteSongsLabel.textColor = UIColor.labelColor;
    self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
    self.deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
    self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
    self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
    self.deleteSongsLabel.text = @"Remove # Songs";
    self.deleteSongsLabel.hidden = YES;
    [self.saveEditContainer addSubview:self.deleteSongsLabel];
    
    self.savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.savePlaylistButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.savePlaylistButton];
    
    self.editPlaylistLabel = [[UILabel alloc] init];
    self.editPlaylistLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.editPlaylistLabel.textColor = UIColor.systemBlueColor;
    self.editPlaylistLabel.textAlignment = NSTextAlignmentCenter;
    self.editPlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
    self.editPlaylistLabel.text = @"Edit";
    [self.saveEditContainer addSubview:self.editPlaylistLabel];
    
    self.editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editPlaylistButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.editPlaylistButton addTarget:self action:@selector(editPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.saveEditContainer addSubview:self.editPlaylistButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.saveEditContainer.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.saveEditContainer.heightAnchor constraintEqualToConstant:50],
        [self.saveEditContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        
        [self.savePlaylistLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.savePlaylistLabel.heightAnchor constraintEqualToAnchor:self.saveEditContainer.heightAnchor multiplier:0.666],
        [self.savePlaylistLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.savePlaylistLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        
        [self.playlistCountLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.playlistCountLabel.heightAnchor constraintEqualToAnchor:self.saveEditContainer.heightAnchor multiplier:0.333],
        [self.playlistCountLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.playlistCountLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor constant:-4],
        
        [self.deleteSongsLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.deleteSongsLabel.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.deleteSongsLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.deleteSongsLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.savePlaylistButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.75],
        [self.savePlaylistButton.leadingAnchor constraintEqualToAnchor:self.saveEditContainer.leadingAnchor],
        [self.savePlaylistButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.savePlaylistButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editPlaylistLabel.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editPlaylistLabel.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editPlaylistLabel.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editPlaylistLabel.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        
        [self.editPlaylistButton.widthAnchor constraintEqualToAnchor:self.saveEditContainer.widthAnchor multiplier:0.25],
        [self.editPlaylistButton.trailingAnchor constraintEqualToAnchor:self.saveEditContainer.trailingAnchor],
        [self.editPlaylistButton.topAnchor constraintEqualToAnchor:self.saveEditContainer.topAnchor],
        [self.editPlaylistButton.bottomAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
    ]];
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.saveEditContainer.bottomAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    self.tableView.rowHeight = Defines.rowHeight;
    	
	[self.tableView reloadData];
    
    [self selectRow];
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
	if (self.isEditing) {
        [self setEditing:NO animated:YES];
        [self hideDeleteButton];
        self.editPlaylistLabel.backgroundColor = UIColor.clearColor;
        self.editPlaylistLabel.textColor = UIColor.systemBlueColor;
        self.editPlaylistLabel.text = @"Edit";
        
        // Reload the table to correct the numbers
        [self.tableView reloadData];
        if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
        }
    } else {
        // Deelect all the rows
        for (int i = 0; i < self.currentPlaylistCount; i++) {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO];
        }
        
		[self setEditing:YES animated:YES];
        self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
        self.editPlaylistLabel.textColor = UIColor.labelColor;
		self.editPlaylistLabel.text = @"Done";
		[self showDeleteButton];
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
                NSString *message = @"Would you like to save this playlist to your device or to your Subsonic server?";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Playlist Location" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Local" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    self.savePlaylistLocal = YES;
                    [self showSavePlaylistAlert];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Server" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    self.savePlaylistLocal = NO;
                    [self showSavePlaylistAlert];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
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
                // Inform the user that the connection failed.
                if (settingsS.isPopupsEnabled) {
                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                
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
    DDLogError(@"[CurrentPlaylistViewController] subsonic error %@: %@", errorCode, message);
    if (settingsS.isPopupsEnabled) {
        [EX2Dispatch runInMainThreadAsync:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
}

- (void)showSavePlaylistAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Playlist" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Playlist name";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = [[[alert textFields] firstObject] text];
        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
            // Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
            NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", name.md5];
            if (test) {
                // If it exists, ask to overwrite
                [self showOverwritePlaylistAlert:name];
            } else {
                NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
                NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
                NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
                NSString *table = playlistS.isShuffle ? shufTable : currTable;
                
                [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
                    [db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", name, name.md5];
                    [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
                    
                    [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
                    if (db.hadError) { DDLogError(@"[CurrentPlaylistViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
                    [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
                    [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
                }];
            }
        } else {
            NSString *tableName = [NSString stringWithFormat:@"splaylist%@", name.md5];
            if ([databaseS.localPlaylistsDbQueue tableExists:tableName]) {
                // If it exists, ask to overwrite
                [self showOverwritePlaylistAlert:name];
            } else {
                [self uploadPlaylist:name];
            }
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showOverwritePlaylistAlert:(NSString *)name {
    NSString *message = [NSString stringWithFormat:@"A playlist named \"%@\" already exists. Would you like to overwrite it?", name];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Overwrite?" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Overwrite" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        // If yes, overwrite the playlist
        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
            NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", settingsS.urlString.md5];
            NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
            NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
            NSString *table = playlistS.isShuffle ? shufTable : currTable;
            
            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", name.md5]];
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
                
                [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
                if (db.hadError) { DDLogError(@"[CurrentPlaylistViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
                [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
                [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
            }];
        } else {
            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", name.md5]];
            }];
            
            [self uploadPlaylist:name];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectRow {
	[self.tableView reloadData];
	if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
	}
}

- (void)dismiss:(id)sender {
    if (self.navigationController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
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
    
//    cell.autoScroll = NO;
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
