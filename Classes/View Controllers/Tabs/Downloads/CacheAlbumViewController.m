////
////  CacheAlbumViewController.m
////  iSub
////
////  Created by Ben Baron on 6/16/10.
////  Copyright 2010 Ben Baron. All rights reserved.
////
//
//#import "CacheAlbumViewController.h"
//#import "Defines.h"
//#import "SavedSettings.h"
//#import "EX2Kit.h"
//#import "Swift.h"
//#import "ISMSCacheQueueManager.h"
//#import "CacheSingleton.h"
//
////LOG_LEVEL_ISUB_DEFAULT
//
//@implementation CacheAlbumViewController
//
////static NSInteger trackSort(id obj1, id obj2, void *context) {
////	NSUInteger track1TrackNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
////	NSUInteger track2TrackNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
////    NSUInteger track1DiscNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:2] intValue];
////    NSUInteger track2DiscNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:2] intValue];
////
////    // first check the disc numbers.  if t1d < t2d, ascending
////    if (track1DiscNum < track2DiscNum) {
////        return NSOrderedAscending;
////    }
////
////    // if they're equal, check the track numbers
////    else if (track1DiscNum == track2DiscNum) {
////        if (track1TrackNum < track2TrackNum) {
////            return NSOrderedAscending;
////        } else if (track1TrackNum == track2TrackNum) {
////            return NSOrderedSame;
////        } else {
////            return NSOrderedDescending;
////        }
////    }
////
////    // if t1d > t2d, descending
////	else return NSOrderedDescending;
////}
//
//- (instancetype)initWithServerId:(NSInteger)serverId level:(NSInteger)level parentPathComponent:(NSString *)parentPathComponent {
//    if (self = [super initWithNibName:nil bundle:nil]) {
//        _serverId = serverId;
//        _level = level;
//        _parentPathComponent = parentPathComponent;
//    }
//    return self;
//}
//
//- (void)viewDidLoad  {
//    [super viewDidLoad];
//    
//    self.title = self.parentPathComponent;
//
//    self.tableView.rowHeight = Defines.rowHeight;
//    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
//    [self loadData];
//    
////    // Sort the subfolders in the same way that Subsonic sorts them (indefinite articles)
////    [self.albums sortUsingComparator:^NSComparisonResult(NSArray* _Nonnull obj1, NSArray* _Nonnull obj2) {
////        NSString *name1 = [obj1 objectAtIndexSafe:1];
////        NSString *name2 = [obj2 objectAtIndexSafe:1];
////        return [name1 caseInsensitiveCompareWithoutIndefiniteArticles:name2];
////    }];
////    [self.tableView reloadData];
//}
//
//- (void)viewWillAppear:(BOOL)animated {
//	[super viewWillAppear:animated];
//		
//    [self addShowPlayerButton];
//
//    [self addHeaderAndIndex];
//	
//	// Set notification receiver for when cached songs are deleted to reload the table
//	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(cachedSongDeleted) name:Notifications.cachedSongDeleted object:nil];
//}
//
//- (void)viewWillDisappear:(BOOL)animated {
//	[super viewWillDisappear:animated];
//	[NSNotificationCenter removeObserverOnMainThread:self name:Notifications.cachedSongDeleted object:nil];
//}
//
//- (void)loadData {
//    self.downloadedFolderAlbums = [Store.shared downloadedFolderAlbumsWithServerId:self.serverId level:self.level parentPathComponent:self.parentPathComponent];
//    self.downloadedSongs = [Store.shared downloadedSongsWithServerId:self.serverId level:self.level parentPathComponent:self.parentPathComponent];
//}
//
//- (void)addHeaderAndIndex {
//    // Create the container view and constrain it to the table
//    UIView *headerView = [[UIView alloc] init];
//    headerView.translatesAutoresizingMaskIntoConstraints = NO;
//    self.tableView.tableHeaderView = headerView;
//    [NSLayoutConstraint activateConstraints:@[
//        [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
//        [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor],
//        [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor]
//    ]];
//    
//    // Create the play all and shuffle buttons and constrain to the container view
//    __weak CacheAlbumViewController *weakSelf = self;
//    PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
//        [HUD show];
//        [EX2Dispatch runInBackgroundAsync:^{
//            [weakSelf loadPlayAllPlaylist:NO];
//        }];
//    } shuffleHandler:^{
//        [HUD showWithMessage:@"Shuffling"];
//        [EX2Dispatch runInBackgroundAsync:^{
//            [weakSelf loadPlayAllPlaylist:YES];
//        }];
//    }];
//    [headerView addSubview:playAllAndShuffleHeader];
//    [NSLayoutConstraint activateConstraints:@[
//        [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
//        [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
//        [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor],
//        [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
//    ]];
//    
//    // Force re-layout using the constraints
//    [self.tableView.tableHeaderView layoutIfNeeded];
//    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
//    
//    // Create the section index
//    // TODO: This is not correct for cached albums, queries need to be rewritten
////    if (self.albums.count > 10) {
////        __block NSArray *secInfo = nil;
////        [databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db) {
////            [db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
////            [db executeUpdate:@"CREATE TEMP TABLE albumIndex (album TEXT)"];
////
////            [db beginTransaction];
////            for (NSNumber *rowId in self.albums) {
////                @autoreleasepool {
////                    [db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM folderAlbum WHERE rowid = ?", rowId];
////                }
////            }
////            [db commit];
////
////            secInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"album"];
////            [db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
////        }];
////
////        if (secInfo) {
////            self.sectionInfo = [NSArray arrayWithArray:secInfo];
////            if ([self.sectionInfo count] < 5) {
////                self.sectionInfo = nil;
////            } else {
////                [self.tableView reloadData];
////            }
////        } else {
////            self.sectionInfo = nil;
////        }
////    }
//}
//
//- (void)cachedSongDeleted {
//    [self loadData];
//    
//	// If the table is empty, pop back one view, otherwise reload the table data
//	if (self.downloadedFolderAlbums.count + self.downloadedSongs.count == 0) {
//		if (UIDevice.isPad) {
//            [SceneDelegate.shared.padRootViewController.currentContentNavigationController popToRootViewControllerAnimated:YES];
//		} else {
//			// Handle the moreNavigationController stupidity
//            UITabBarController *tabBarController = SceneDelegate.shared.tabBarController;
//			if (tabBarController.selectedIndex == 4) {
//				[tabBarController.moreNavigationController popToViewController:tabBarController.moreNavigationController.viewControllers[1] animated:YES];
//			} else {
//				[(UINavigationController*)tabBarController.selectedViewController popToRootViewControllerAnimated:YES];
//			}
//		}
//	} else {
//		[self.tableView reloadData];
//	}
//}
//
//- (void)loadPlayAllPlaylist:(BOOL)shuffle {
//    NSArray<ISMSSong*> *songs = [Store.shared songsRecursiveWithServerId:self.serverId level:self.level parentPathComponent:self.parentPathComponent];
//    (void)[Store.shared playSongWithPosition:0 songs:songs];
//    if (shuffle) {
//        [PlayQueue.shared shuffleToggle];
//    }
//}
//
//- (void)dealloc {
//	[NSNotificationCenter removeObserverOnMainThread:self];
//}
//
//#pragma mark Table view methods
//
//- (DownloadedFolderAlbum *)downloadedFolderAlbumAtIndexPath:(NSIndexPath *)indexPath {
//    if (indexPath.section != 0 || indexPath.row >= self.downloadedFolderAlbums.count) return nil;
//    return self.downloadedFolderAlbums[indexPath.row];
//}
//
//- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
//    if (indexPath.section != 1 || indexPath.row >= self.downloadedSongs.count) return nil;
//    DownloadedSong *downloadedSong = self.downloadedSongs[indexPath.row];
//    return [Store.shared songWithServerId:downloadedSong.serverId songId:downloadedSong.songId];
//}
//
////// Following 2 methods handle the right side index
////- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
////	NSMutableArray *indexes = [[NSMutableArray alloc] init];
////	for (int i = 0; i < self.sectionInfo.count; i++) {
////		[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
////	}
////	return indexes;
////}
////
////- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
////	if (index == 0) {
////		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
////	} else {
////		NSUInteger row = [[[self.sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
////		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
////		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
////	}
////
////	return -1;
////}
//
//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//    return 2;
//}
//
//// Customize the number of rows in the table view.
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    return section == 0 ? self.downloadedFolderAlbums.count : self.downloadedSongs.count;
//}
//
//// Customize the appearance of table view cells.
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
//	if (indexPath.section == 0) {
//        // Album
//        [cell showCached:NO number:NO art:YES secondary:NO duration:NO];
//        [cell updateWithModel:[self downloadedFolderAlbumAtIndexPath:indexPath]];
//	} else {
//        // Song
//        ISMSSong *song = [self songAtIndexPath:indexPath];
//        BOOL showNumber = NO;
//        if (song.track > 0) {
//            showNumber = NO;
//            cell.number = song.track;
//        }
//        [cell showCached:NO number:showNumber art:NO secondary:YES duration:YES];
//        [cell updateWithModel:song];
//	}
//    return cell;
//}
//
//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//	if (!indexPath) return;
//    
//    if (indexPath.section == 0) {
//        DownloadedFolderAlbum *downloadedFolderAlbum = [self downloadedFolderAlbumAtIndexPath:indexPath];
//        CacheAlbumViewController *controller = [[CacheAlbumViewController alloc] initWithServerId:downloadedFolderAlbum.serverId level:downloadedFolderAlbum.level + 1 parentPathComponent:downloadedFolderAlbum.name];
//        [self pushViewControllerCustom:controller];
//    } else {
//        // TODO: Optimize this
//        NSMutableArray<ISMSSong*> *songs = [NSMutableArray arrayWithCapacity:self.downloadedSongs.count];
//        for (DownloadedSong *downloadedSong in self.downloadedSongs) {
//            [songs addObject:[Store.shared songWithDownloadedSong:downloadedSong]];
//        }
//        if ([Store.shared playSongWithPosition:indexPath.row songs:songs]) {
//            [self showPlayer];
//        }
//    }
//}
//
//- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
////    if (indexPath.row < self.albums.count) {
////        // Custom queue and delete actions
////        ISMSFolderAlbum *folderAlbum = [self folderAlbumAtIndexPath:indexPath];
////        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
////            [HUD show];
////            [EX2Dispatch runInBackgroundAsync:^{
////                NSMutableArray *newSegments = [NSMutableArray arrayWithArray:self.segments];
////                [newSegments addObject:folderAlbum.name];
////
////                NSUInteger segment = [newSegments count];
////
////                NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE segs = %lu", (unsigned long)(segment+1)];
////                for (int i = 1; i <= segment; i++) {
////                    [query appendFormat:@" AND seg%i = ? ", i];
////                }
////                [query appendFormat:@"ORDER BY seg%lu COLLATE NOCASE", (long)segment+1];
////
////                NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:20];
////                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
////                    FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
////                    while ([result next]) {
////                        NSString *md5 = [result stringForColumnIndex:0];
////                        if (md5) [songMd5s addObject:md5];
////                    }
////                    [result close];
////                }];
////
////                for (NSString *md5 in songMd5s) {
////                    @autoreleasepool {
////                        ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
////                        [aSong addToCurrentPlaylistDbQueue];
////                    }
////                }
////
////                [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.currentPlaylistSongsQueued];
////
////                [EX2Dispatch runInMainThreadAsync:^{
////                    [HUD hide];
////                }];
////            }];
////        } deleteHandler:^{
////            [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
////            [EX2Dispatch runInBackgroundAsync:^{
////                NSMutableArray *newSegments = [NSMutableArray arrayWithArray:self.segments];
////                [newSegments addObject:folderAlbum.name];
////
////                NSUInteger segment = [newSegments count];
////
////                NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? "];
////                for (int i = 2; i <= segment; i++) {
////                    [query appendFormat:@" AND seg%i = ? ", i];
////                }
////
////                DDLogVerbose(@"[CacheAlbumViewController] query: %@, parameter: %@", query, newSegments);
////                NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
////                [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db) {
////                    FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
////                    while ([result next]) {
////                        @autoreleasepool {
////                            NSString *md5 = [result stringForColumnIndex:0];
////                            if (md5) [songMd5s addObject:md5];
////                        }
////                    }
////                    [result close];
////                }];
////
////                DDLogVerbose(@"[CacheAlbumViewController] songMd5s: %@", songMd5s);
////                for (NSString *md5 in songMd5s) {
////                    @autoreleasepool {
////                        [ISMSSong removeSongFromCacheDbByMD5:md5];
////                    }
////                }
////
////                [cacheS findCacheSize];
////
////                // Reload the cached songs table
////                [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.cachedSongDeleted];
////
////                if (!cacheQueueManagerS.isQueueDownloading) {
////                    [cacheQueueManagerS startDownloadQueue];
////                }
////
////                [EX2Dispatch runInMainThreadAsync:^{
////                    [HUD hide];
////                }];
////            }];
////        }];
////    } else {
////        NSString *md5 = [[self.songs objectAtIndexSafe:(indexPath.row - self.albums.count)] firstObject];
////        return [SwipeAction downloadQueueAndDeleteConfigWithDownloadHandler:nil queueHandler:^{
////            [[ISMSSong songFromCacheDbQueue:md5] addToCurrentPlaylistDbQueue];
////            [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.currentPlaylistSongsQueued];
////        } deleteHandler:^{
////            [ISMSSong removeSongFromCacheDbByMD5:md5];
////            [cacheS findCacheSize];
////            // Reload the cached songs table
////            [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.cachedSongDeleted];
////        }];
////    }
//    return nil;
//}
//
//@end
