//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "FolderAlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <MediaPlayer/MediaPlayer.h>

@interface FolderAlbumViewController() <APILoaderDelegate>
@end

@implementation FolderAlbumViewController

#pragma mark Lifecycle

- (instancetype)initWithFolderArtist:(ISMSFolderArtist *)folderArtist orFolderAlbum:(ISMSFolderAlbum *)folderAlbum {
	if (folderArtist == nil && folderAlbum == nil) return nil;
	
    if (self = [super init]) {
		if (folderArtist != nil) {
			self.title = folderArtist.name;
			_folderId = folderArtist.folderId;
			_folderArtist = folderArtist;
		} else {
			self.title = folderAlbum.name;
			_folderId = folderAlbum.folderId;
			_folderAlbum = folderAlbum;
		}
        _dataModel = [[SubfolderDAO alloc] initWithParentFolderId:_folderId delegate:self];
		
        if (self.dataModel.hasLoaded) {
            [self.tableView reloadData];
            [self addHeaderAndIndex];
        } else {
            [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
            [self.dataModel startLoad];
        }
	}
	
	return self;
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    				
    // Add the pull to refresh view
    __weak FolderAlbumViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [viewObjectsS showAlbumLoadingScreen:weakSelf.view sender:weakSelf];
        [weakSelf.dataModel startLoad];
    }];
    
    self.tableView.rowHeight = Defines.rowHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = UIColor.clearColor;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated  {
	[super viewWillAppear:animated];
	
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"music.quarternote.3"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[self.tableView reloadData];
		
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadData) name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadData) name:ISMSNotification_SongPlaybackStarted];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[self.dataModel cancelLoad];
	
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_SongPlaybackStarted];
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
	self.dataModel.delegate = nil;
}

#pragma mark Loading

- (void)cancelLoad {
	[self.dataModel cancelLoad];
    [self.refreshControl endRefreshing];
	[viewObjectsS hideLoadingScreen];
}

// Autolayout solution described here: https://medium.com/@aunnnn/table-header-view-with-autolayout-13de4cfc4343
- (void)addHeaderAndIndex {
	if (self.dataModel.songCount == 0 && self.dataModel.folderCount == 0) {
		self.tableView.tableHeaderView = nil;
    } else {
        // Create the container view and constrain it to the table
        UIView *headerView = [[UIView alloc] init];
        headerView.translatesAutoresizingMaskIntoConstraints = NO;
        self.tableView.tableHeaderView = headerView;
        [NSLayoutConstraint activateConstraints:@[
            [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
            [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor],
            [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor]
        ]];
        
        // Create the play all and shuffle buttons and constrain to the container view
        __weak FolderAlbumViewController *weakSelf = self;
        PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
            [SongLoader playAllWithFolderId:weakSelf.folderId];
        } shuffleHandler:^{
            [SongLoader shuffleAllWithFolderId:weakSelf.folderId];
        }];
        [headerView addSubview:playAllAndShuffleHeader];
        [NSLayoutConstraint activateConstraints:@[
            [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
            [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
            [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
        ]];
        
        if (self.dataModel.songCount > 0) {
            // Create the album header view and constrain to the container view
            AlbumTableViewHeader *albumHeader = [[AlbumTableViewHeader alloc] initWithFolderAlbum:self.folderAlbum tracks:self.dataModel.songCount duration:self.dataModel.duration];
            [headerView addSubview:albumHeader];
            [NSLayoutConstraint activateConstraints:@[
                [albumHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
                [albumHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
                [albumHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor]
            ]];
            
            // Constrain the buttons below the album header
            [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:albumHeader.bottomAnchor].active = YES;
        } else {
            // Play All and Shuffle buttons only
            [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor].active = YES;
        }
        
        // Force re-layout using the constraints
        [self.tableView.tableHeaderView layoutIfNeeded];
        self.tableView.tableHeaderView = self.tableView.tableHeaderView;
    }
	
//	self.sectionInfo = self.dataModel.sectionInfo;
//	if (self.sectionInfo)
//		[self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark Table view methods

//// Following 2 methods handle the right side index
//- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
//	NSMutableArray *indexes = [[NSMutableArray alloc] init];
//	for (int i = 0; i < self.sectionInfo.count; i++)
//	{
//		[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] firstObject]];
//	}
//	return indexes;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
//	NSUInteger row = [[[self.sectionInfo objectAtIndexSafe:index] objectAtIndexSafe:1] intValue];
//	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
//	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
//
//	return -1;
//}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
    return section == 0 ? self.dataModel.folderCount : self.dataModel.songCount;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    if (indexPath.section == 0) {
        // Album
        cell.hideSecondaryLabel = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = YES;
        [cell updateWithModel:[self.dataModel folderAlbumWithIndexPath:indexPath]];
    } else {
        // Song
        cell.hideSecondaryLabel = NO;
        cell.hideCoverArt = YES;
        cell.hideDurationLabel = NO;
        ISMSSong *song = [self.dataModel songWithIndexPath:indexPath];
        [cell updateWithModel:song];
        if (song.track == 0) {
            cell.hideNumberLabel = YES;
        } else {
            cell.hideNumberLabel = NO;
            cell.number = song.track;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
    if (indexPath.row < self.dataModel.folderCount) {
        ISMSFolderAlbum *folderAlbum = [self.dataModel folderAlbumWithIndexPath:indexPath];
        FolderAlbumViewController *folderAlbumViewController = [[FolderAlbumViewController alloc] initWithFolderArtist:nil orFolderAlbum:folderAlbum];
        [self pushViewControllerCustom:folderAlbumViewController];
    } else {
        ISMSSong *playedSong = [self.dataModel playSongWithIndexPath:indexPath];
        if (!playedSong.isVideo) {
            [self showPlayer];
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.dataModel.folderCount) {
        return [SwipeAction downloadAndQueueConfigWithModel:[self.dataModel folderAlbumWithIndexPath:indexPath]];
    } else {
        ISMSSong *song = [self.dataModel songWithIndexPath:indexPath];
        if (!song.isVideo) {
            return [SwipeAction downloadAndQueueConfigWithModel:song];
        }
    }
    return nil;
}

#pragma mark APILoader delegate

- (void)loadingFinished:(APILoader *)loader {
    [viewObjectsS hideLoadingScreen];
    
    [self.tableView reloadData];
    [self addHeaderAndIndex];
    
    [self.refreshControl endRefreshing];
}

- (void)loadingFailed:(APILoader *)loader error:(NSError *)error {
    if (settingsS.isPopupsEnabled) {
        NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %li: %@", (long)error.code, error.localizedDescription];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
	
	[viewObjectsS hideLoadingScreen];
	
    [self.refreshControl endRefreshing];
}

@end
