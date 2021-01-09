//
//  TagArtistViewController.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "TagArtistViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
//#import "SUSTagArtistDAO.h"
//#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "TagAlbumViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation TagArtistViewController

#pragma mark Lifecycle

- (instancetype)initWithTagArtist:(ISMSTagArtist *)tagArtist {
    if (tagArtist == nil) return nil;
    
    if (self = [super init]) {
        self.title = tagArtist.name;
        self.tagArtist = tagArtist;
        self.dataModel = [[TagArtistDAO alloc] initWithTagArtistId:tagArtist.artistId delegate:self];
        
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
    __weak TagArtistViewController *weakSelf = self;
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
//    if (self.dataModel.songsCount == 0 && self.dataModel.albumsCount == 0) {
//        self.tableView.tableHeaderView = nil;
//    } else {
//        // Create the container view and constrain it to the table
//        UIView *headerView = [[UIView alloc] init];
//        headerView.translatesAutoresizingMaskIntoConstraints = NO;
//        self.tableView.tableHeaderView = headerView;
//        [NSLayoutConstraint activateConstraints:@[
//            [headerView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
//            [headerView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor],
//            [headerView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor]
//        ]];
//
//        // Create the play all and shuffle buttons and constrain to the container view
//        __weak FolderAlbumViewController *weakSelf = self;
//        PlayAllAndShuffleHeader *playAllAndShuffleHeader = [[PlayAllAndShuffleHeader alloc] initWithPlayAllHandler:^{
//            [databaseS playAllSongs:weakSelf.folderId folderArtist:weakSelf.folderArtist];
//        } shuffleHandler:^{
//            [databaseS shuffleAllSongs:weakSelf.folderId folderArtist:weakSelf.folderArtist];
//        }];
//        [headerView addSubview:playAllAndShuffleHeader];
//        [NSLayoutConstraint activateConstraints:@[
//            [playAllAndShuffleHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
//            [playAllAndShuffleHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
//            [playAllAndShuffleHeader.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
//        ]];
//
//        if (self.dataModel.songsCount > 0) {
//            // Create the album header view and constrain to the container view
//            AlbumTableViewHeader *albumHeader = [[AlbumTableViewHeader alloc] initWithFolderAlbum:self.folderAlbum tracks:self.dataModel.songsCount duration:self.dataModel.folderLength];
//            [headerView addSubview:albumHeader];
//            [NSLayoutConstraint activateConstraints:@[
//                [albumHeader.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
//                [albumHeader.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
//                [albumHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor]
//            ]];
//
//            // Constrain the buttons below the album header
//            [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:albumHeader.bottomAnchor].active = YES;
//        } else {
//            // Play All and Shuffle buttons only
//            [playAllAndShuffleHeader.topAnchor constraintEqualToAnchor:headerView.topAnchor].active = YES;
//        }
//
//        // Force re-layout using the constraints
//        [self.tableView.tableHeaderView layoutIfNeeded];
//        self.tableView.tableHeaderView = self.tableView.tableHeaderView;
//    }
//
//    self.sectionInfo = self.dataModel.sectionInfo;
//    if (self.sectionInfo)
//        [self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark Table view methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
    return self.dataModel.albumCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideSecondaryLabel = NO;
    cell.hideNumberLabel = YES;
    cell.hideCoverArt = NO;
    cell.hideDurationLabel = YES;
    [cell updateWithModel:[self.dataModel tagAlbumWithIndexPath:indexPath]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    
    ISMSTagAlbum *tagAlbum = [self.dataModel tagAlbumWithIndexPath:indexPath];
    TagAlbumViewController *controller = [[TagAlbumViewController alloc] initWithTagAlbum:tagAlbum];
    [self pushViewControllerCustom:controller];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [SwipeAction downloadAndQueueConfigWithModel:[self.dataModel tagAlbumWithIndexPath:indexPath]];
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
