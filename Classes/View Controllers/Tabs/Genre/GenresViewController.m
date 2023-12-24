//
//  GenresViewController.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresViewController.h"
#import "GenresArtistViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "ISMSSong+DAO.h"

@implementation GenresViewController

#pragma mark View lifecycle

- (void)viewDidLoad  {
    [super viewDidLoad];
	
	self.isNoGenresScreenShowing = NO;
	
	self.title = @"Genres";
	
    if (settingsS.isOfflineMode) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsAction:)];
    }
    
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)showNoGenresScreen {
	if (self.isNoGenresScreenShowing == NO) {
		self.isNoGenresScreenShowing = YES;
		self.noGenresScreen = [[UIImageView alloc] init];
		self.noGenresScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noGenresScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noGenresScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noGenresScreen.image = [UIImage imageNamed:@"loading-screen-image"];
		self.noGenresScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:30];
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isOfflineMode) {
			[textLabel setText:@"No Cached\nSongs"];
		}
		else {
			[textLabel setText:@"Load The\nSongs Tab\nFirst"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noGenresScreen addSubview:textLabel];
		
		[self.view addSubview:self.noGenresScreen];
	}
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated  {
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Defines.musicNoteImageSystemName] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
	
	if (settingsS.isOfflineMode) {
		if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0) {
			[self showNoGenresScreen];
		}
	} else {
		if ([databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0) {
			[self showNoGenresScreen];
		}
	}

	[self.tableView reloadData];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
	if (self.isNoGenresScreenShowing == YES) {
		[self.noGenresScreen removeFromSuperview];
		self.isNoGenresScreenShowing = NO;
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

#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1; 
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (settingsS.isOfflineMode) {
		return [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
    } else {
		return [databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideSecondaryLabel = YES;
    cell.hideDurationLabel = YES;
    cell.hideCoverArt = YES;
    cell.hideNumberLabel = YES;
    
    NSString *name = nil;
    if (settingsS.isOfflineMode) {
        name = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
    } else {
        name = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
    }
    [cell updateWithPrimaryText:name secondaryText:nil];
    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
	
    GenresArtistViewController *artistViewController = [[GenresArtistViewController alloc] initWithNibName:@"GenresArtistViewController" bundle:nil];
    if (settingsS.isOfflineMode) {
        NSString *title = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
        artistViewController.title = [NSString stringWithString:title ? title : @""];
    } else {
        NSString *title = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
        artistViewController.title = [NSString stringWithString:title ? title : @""];
    }
    artistViewController.listOfArtists = [NSMutableArray arrayWithCapacity:1];

    FMDatabaseQueue *dbQueue;
    NSString *query;
    
    if (settingsS.isOfflineMode)  {
        dbQueue = databaseS.songCacheDbQueue;
        query = @"SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
    } else {
        dbQueue = databaseS.genresDbQueue;
        query = @"SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
    }
    
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:query, artistViewController.title];
        if ([db hadError]) {
            //DLog(@"Error grabbing the artists for this genre... Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
        } else {
            while ([result next]) {
                NSString *artist = [result stringForColumnIndex:0];
                if (artist) [artistViewController.listOfArtists addObject:artist];
            }
        }
        [result close];
    }];
    
    [self pushViewControllerCustom:artistViewController];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = nil;
    if (settingsS.isOfflineMode) {
        name = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
    } else {
        name = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
    }
    
    if (settingsS.isOfflineMode) {
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.songCacheDbQueue;
                NSString *query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";

                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name];
                    
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
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                [viewObjectsS hideLoadingScreen];
            }];
        } deleteHandler:nil];
    } else {
        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.genresDbQueue;
                NSString *query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name];
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
                        [aSong addToCacheQueueDbQueue];
                    }
                }
                
                // Hide the loading screen
                [viewObjectsS hideLoadingScreen];
            }];
        } queueHandler:^{
            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
            [EX2Dispatch runInMainThreadAfterDelay:0.05 block:^{
                FMDatabaseQueue *dbQueue = databaseS.genresDbQueue;
                NSString *query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
                
                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
                [dbQueue inDatabase:^(FMDatabase *db) {
                    FMResultSet *result = [db executeQuery:query, name];
                    
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
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
                
                [viewObjectsS hideLoadingScreen];
            }];
        } deleteHandler:nil];
    }
}

@end
