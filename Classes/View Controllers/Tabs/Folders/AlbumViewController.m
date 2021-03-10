//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "SUSSubFolderDAO.h"
#import "ISMSArtist.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation AlbumViewController

#pragma mark Lifecycle

- (AlbumViewController *)initWithArtist:(ISMSArtist *)anArtist orAlbum:(ISMSAlbum *)anAlbum {
	if (anArtist == nil && anAlbum == nil) return nil;
	
	if (self = [super initWithNibName:@"AlbumViewController" bundle:nil]) {
		self.sectionInfo = nil;
		
		if (anArtist != nil) {
			self.title = anArtist.name;
			self.myId = anArtist.artistId;
			self.myArtist = anArtist;
			self.myAlbum = nil;
		} else {
			self.title = anAlbum.title;
			self.myId = anAlbum.albumId;
			self.myArtist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			self.myAlbum = anAlbum;
		}
		
		self.dataModel = [[SUSSubFolderDAO alloc] initWithDelegate:self andId:self.myId andArtist:self.myArtist];
		
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
    __weak AlbumViewController *weakSelf = self;
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
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Defines.musicNoteImageSystemName] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
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
	if (self.dataModel.songsCount == 0 && self.dataModel.albumsCount == 0) {
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
        __weak AlbumViewController *weakSelf = self;
        PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
            [databaseS playAllSongs:weakSelf.myId artist:weakSelf.myArtist];
        } shuffleHandler:^{
            [databaseS shuffleAllSongs:weakSelf.myId artist:weakSelf.myArtist];
        }];
        [headerView addSubview:playAllAndShuffleHeader];
        [NSLayoutConstraint activateConstraints:@[
            [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
            [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
            [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
        ]];
        
        if (self.dataModel.songsCount > 0) {
            // Create the album header view and constrain to the container view
            AlbumTableViewHeader *albumHeader = [[AlbumTableViewHeader alloc] initWithAlbum:self.myAlbum tracks:self.dataModel.songsCount duration:self.dataModel.folderLength];
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
	
	self.sectionInfo = self.dataModel.sectionInfo;
	if (self.sectionInfo)
		[self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	for (int i = 0; i < self.sectionInfo.count; i++)
	{
		[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] firstObject]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
	NSUInteger row = [[[self.sectionInfo objectAtIndexSafe:index] objectAtIndexSafe:1] intValue];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return self.dataModel.totalCount;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    if (indexPath.row < self.dataModel.albumsCount) {
        // Album
        cell.hideSecondaryLabel = YES;
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = YES;
        [cell updateWithModel:[self.dataModel albumForTableViewRow:indexPath.row]];
    } else {
        // Song
        cell.hideSecondaryLabel = NO;
        cell.hideCoverArt = YES;
        cell.hideDurationLabel = NO;
        ISMSSong *song = [self.dataModel songForTableViewRow:indexPath.row];
        [cell updateWithModel:song];
        if (song.track == nil || song.track.intValue == 0) {
            cell.hideNumberLabel = YES;
        } else {
            cell.hideNumberLabel = NO;
            cell.number = song.track.intValue;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
    if (indexPath.row < self.dataModel.albumsCount) {
        ISMSAlbum *anAlbum = [self.dataModel albumForTableViewRow:indexPath.row];
        AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
        [self pushViewControllerCustom:albumViewController];
    } else {
        ISMSSong *playedSong = [self.dataModel playSongAtTableViewRow:indexPath.row];
        if (!playedSong.isVideo) {
            [self showPlayer];
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.dataModel.albumsCount) {
        return [SwipeAction downloadAndQueueConfigWithModel:[self.dataModel albumForTableViewRow:indexPath.row]];
    } else {
        ISMSSong *song = [self.dataModel songForTableViewRow:indexPath.row];
        if (!song.isVideo) {
            return [SwipeAction downloadAndQueueConfigWithModel:song];
        }
    }
    return nil;
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    if (settingsS.isPopupsEnabled) {
        NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %li: %@", (long)error.code, error.localizedDescription];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
	
	[viewObjectsS hideLoadingScreen];
	
    [self.refreshControl endRefreshing];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
    [self.refreshControl endRefreshing];
}

@end
