//
//  PlaylistSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongsViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "NSError+ISMSError.h"
#import "SUSServerPlaylist.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "SUSLoader.h"

LOG_LEVEL_ISUB_DEFAULT

@interface PlaylistSongsViewController()
@property (strong) NSURLSessionDataTask *dataTask;
@end

@implementation PlaylistSongsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.localPlaylist) {
        self.title = self.localPlaylist.name;

		if (!settingsS.isOfflineMode) {
			UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
//			headerView.backgroundColor = viewObjectsS.darkNormal;

			UILabel *sendLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
			sendLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendLabel.backgroundColor = [UIColor clearColor];
            sendLabel.textColor = UIColor.labelColor;
			sendLabel.textAlignment = NSTextAlignmentCenter;
			sendLabel.font = [UIFont boldSystemFontOfSize:24];
			sendLabel.text = @"Save to Server";
			[headerView addSubview:sendLabel];

			UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
			sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendButton.frame = CGRectMake(0, 0, 320, 50);
			[sendButton addTarget:self action:@selector(uploadPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
			[headerView addSubview:sendButton];

			self.tableView.tableHeaderView = headerView;
		}
	} else {
        // TODO: implement this
//        self.title = self.serverPlaylist.playlistName;
//        self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];
//		[self.tableView reloadData];
//
//        // Add the pull to refresh view
//        __weak PlaylistSongsViewController *weakSelf = self;
//        self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
//            [weakSelf loadData];
//        }];
	}

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)loadData {
//    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.serverPlaylist.playlistId) forKey:@"id"];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
//    self.dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        if (error) {
//            [EX2Dispatch runInMainThreadAsync:^{
//                if (settingsS.isPopupsEnabled) {
//                    NSString *message = [NSString stringWithFormat:@"There was an error loading the playlist.\n\nError %li: %@", (long)error.code, error.localizedDescription];
//                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
//                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
//                    [self presentViewController:alert animated:YES completion:nil];
//                }
//                
//                self.tableView.scrollEnabled = YES;
//                [viewObjectsS hideLoadingScreen];
//                [self.refreshControl endRefreshing];
//            }];
//        } else {
//            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
//            if (!root.isValid) {
//                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
//                // TODO: Handle this error
//            } else {
//                RXMLElement *error = [root child:@"error"];
//                if (error.isValid) {
//                    //NSString *code = [error attribute:@"code"];
//                    //NSString *message = [error attribute:@"message"];
//                    //[self subsonicErrorCode:[code intValue] message:message];
//                    // TODO: Handle this error
//                } else {
//                    // TODO: Handle !isValid case
//                    if ([[root child:@"playlist"] isValid]) {
//                        [databaseS removeServerPlaylistTable:self.md5];
//                        [databaseS createServerPlaylistTable:self.md5];
//                        [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
//                            ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
//                            [aSong insertIntoServerPlaylistWithPlaylistId:self.md5];
//                        }];
//                    }
//                }
//            }
//            
//            self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];
//            
//            [EX2Dispatch runInMainThreadAsync:^{
//                [self.tableView reloadData];
//                [self.refreshControl endRefreshing];
//                [viewObjectsS hideLoadingScreen];
//                self.tableView.scrollEnabled = YES;
//            }];
//        }
//    }];
//    [self.dataTask resume];
//    
//    self.tableView.scrollEnabled = NO;
//    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}	

- (void)cancelLoad {
    [self.dataTask cancel];
    self.dataTask = nil;
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	if (!self.localPlaylist) {
        [self.refreshControl endRefreshing];
	}
}

- (void)viewWillAppear:(BOOL)animated  {
    [super viewWillAppear:animated];
    
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"music.quarternote.3"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}

	if (self.localPlaylist) {
		[self.tableView reloadData];
	} else {
        // TODO: implement this
//		if (self.playlistCount == 0) {
//			[self loadData];
//		}
	}
}

- (void) settingsAction:(id)sender  {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)uploadPlaylistAction:(id)sender {
    // TODO: implement this
//	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.title), @"name", nil];
//
//	NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5];
//	NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:query];
//	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
//	for (int i = 1; i <= count; i++) {
//		@autoreleasepool {
//			NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", self.md5, i];
//			NSString *songId = [databaseS.localPlaylistsDbQueue stringForQuery:query];
//
//			[songIds addObject:n2N(songId)];
//		}
//	}
//	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
//
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
//    self.dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        if (error) {
//            if (settingsS.isPopupsEnabled) {
//                [EX2Dispatch runInMainThreadAsync:^{
//                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
//                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
//                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
//                    [self presentViewController:alert animated:YES completion:nil];
//                }];
//            }
//        } else {
//            DDLogVerbose(@"[PlaylistSongsViewController] upload playlist response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
//            if (!root.isValid) {
//                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
//                [self subsonicErrorCode:nil message:error.description];
//            } else {
//                RXMLElement *error = [root child:@"error"];
//                if (error.isValid) {
//                    NSString *code = [error attribute:@"code"];
//                    NSString *message = [error attribute:@"message"];
//                    [self subsonicErrorCode:code message:message];
//                }
//            }
//        }
//
//        [EX2Dispatch runInMainThreadAsync:^{
//            self.tableView.scrollEnabled = YES;
//            [viewObjectsS hideLoadingScreen];
//            [self.refreshControl endRefreshing];
//        }];
//    }];
//    [self.dataTask resume];
//
//    self.tableView.scrollEnabled = NO;
//    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    DDLogError(@"[PlayistSongsViewController] subsonic error %@: %@", errorCode, message);
    if (settingsS.isPopupsEnabled) {
        [EX2Dispatch runInMainThreadAsync:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
}

#pragma mark Table view methods

- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
    if (self.localPlaylist) {
        return [Store.shared songWithLocalPlaylistId:self.localPlaylist.playlistId position:indexPath.row];
    } else {
        // TODO: implement this
//        return [ISMSSong songFromServerPlaylistId:self.md5 row:indexPath.row];
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.localPlaylist.songCount;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = NO;
    cell.hideCoverArt = NO;
    cell.hideDurationLabel = NO;
    cell.hideSecondaryLabel = NO;
    cell.number = indexPath.row + 1;
    [cell updateWithModel:[self songAtIndexPath:indexPath]];
    return cell;
}

- (void)didSelectRowInternal:(NSIndexPath *)indexPath {
    // TODO: implement this
//	// Clear the current playlist
//	if (settingsS.isJukeboxEnabled) {
//		[databaseS resetJukeboxPlaylist];
//		[jukeboxS clearRemotePlaylist];
//	} else {
//		[databaseS resetCurrentPlaylistDb];
//	}
//
//	PlayQueue.shared.isShuffle = NO;
	
	/*for (int i = 0; i < self.playlistCount; i++)
	{
		@autoreleasepool
		{
			ISMSSong *aSong;
			if (self.isLocalPlaylist)
			{
				aSong = [ISMSSong songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
			}
			else
			{
				aSong = [ISMSSong songFromServerPlaylistId:self.md5 row:i];
			}
			
			[aSong addToCurrentPlaylistDbQueue];
		}
	}*/
	
	// Need to do this for speed (NOTE: haha well 10 years ago maybe, but probably not now)
//	NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
//	NSString *currTableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//	NSString *playTableName = [NSString stringWithFormat:@"%@%@", self.isLocalPlaylist ? @"playlist" : @"splaylist", self.md5];
//	[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
//		 [db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
//		 if ([db hadError]) { DDLogError(@"[PlaylistSongsViewController] Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
//		 
//		 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ SELECT * FROM %@", currTableName, playTableName]];
//		 [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
//	 }];
//	
//    if (settingsS.isJukeboxEnabled) {
//		[jukeboxS replacePlaylistWithLocal];
//    }
//
//    [viewObjectsS hideLoadingScreen];
//    
//    ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
//    if (!playedSong.isVideo) {
//        [self showPlayer];
//    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
    
    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
    [self performSelector:@selector(didSelectRowInternal:) withObject:indexPath afterDelay:0.05];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISMSSong *song = [self songAtIndexPath:indexPath];
    if (!song.isVideo) {
        return [SwipeAction downloadAndQueueConfigWithModel:song];
    }
    return nil;
}

@end
