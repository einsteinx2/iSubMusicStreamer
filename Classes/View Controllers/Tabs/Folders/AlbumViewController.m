//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "EGORefreshTableHeaderView.h"
#import "ModalAlbumArtViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "CustomUIAlertView.h"
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

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    
    return YES;
}

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
    
    if (IS_IOS7()) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
	
	self.albumInfoArtView.delegate = self;
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		
	// Add the pull to refresh view
	self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	self.refreshHeaderView.backgroundColor = [UIColor whiteColor];
	[self.tableView addSubview:self.refreshHeaderView];
    
    self.tableView.rowHeight = 60.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    
	if (IS_IPAD()) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createReflection) name:@"createReflection"  object:nil];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated  {
	[super viewWillAppear:animated];
	
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[self.tableView reloadData];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:ISMSNotification_SongPlaybackStarted object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[self.dataModel cancelLoad];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];	
}

- (void)didReceiveMemoryWarning  {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.albumInfoArtView.delegate = nil;
	self.dataModel.delegate = nil;
}

#pragma mark Loading

- (void)cancelLoad {
	[self.dataModel cancelLoad];
	[self dataSourceDidFinishLoadingNewData];
	[viewObjectsS hideLoadingScreen];
}

- (void)createReflection {
	self.albumInfoArtReflection.image = [self.albumInfoArtView reflectedImageWithHeight:self.albumInfoArtReflection.height];
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView {
	// Make sure to set the reflection again once the art loads
	[self createReflection];
}

- (void)addHeaderAndIndex {
	if (self.dataModel.songsCount == 0 && self.dataModel.albumsCount == 0)
	{
		self.tableView.tableHeaderView = nil;
	} else if (self.dataModel.songsCount > 0) {
		if (!self.tableView.tableHeaderView) {
			CGFloat headerHeight = self.albumInfoView.height + self.playAllShuffleAllView.height;
			CGRect headerFrame = CGRectMake(0., 0., 320, headerHeight);
			UIView *headerView = [[UIView alloc] initWithFrame:headerFrame];
			
			self.albumInfoArtView.isLarge = YES;
			
			[headerView addSubview:self.albumInfoView];
			
			self.playAllShuffleAllView.y = self.albumInfoView.height;
			[headerView addSubview:self.playAllShuffleAllView];
			
			self.tableView.tableHeaderView = headerView;
		}
		
		if (!self.myAlbum) {
			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
			ISMSSong *aSong = [self.dataModel songForTableViewRow:self.dataModel.albumsCount];
			anAlbum.title = aSong.album;
			anAlbum.artistName = aSong.artist;
			anAlbum.coverArtId = aSong.coverArtId;
			self.myAlbum = anAlbum;
		}
		
		self.albumInfoArtView.coverArtId = self.myAlbum.coverArtId;
        self.albumInfoArtistLabel.text = self.myAlbum.artistName;
        self.albumInfoAlbumLabel.text = self.myAlbum.title;
		
        self.albumInfoDurationLabel.text = [NSString formatTime:self.dataModel.folderLength];
        self.albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%lu Tracks", (unsigned long)self.dataModel.songsCount];
        if (self.dataModel.songsCount == 1) {
            self.albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%lu Track", (unsigned long)self.dataModel.songsCount];
        }
		
		// Create reflection
		[self createReflection];
		
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	} else {
		self.tableView.tableHeaderView = self.playAllShuffleAllView;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
	
	self.sectionInfo = self.dataModel.sectionInfo;
	if (self.sectionInfo)
		[self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)expandCoverArt:(id)sender {
	if (self.myAlbum.coverArtId) {
		ModalAlbumArtViewController *largeArt = nil;
		largeArt = [[ModalAlbumArtViewController alloc] initWithAlbum:self.myAlbum
													   numberOfTracks:self.dataModel.songsCount
														  albumLength:self.dataModel.folderLength];
        if (IS_IPAD()) {
			[appDelegateS.ipadRootViewController presentViewController:largeArt animated:YES completion:nil];
        } else {
            [self presentViewController:largeArt animated:YES completion:nil];
        }
	}
}

- (IBAction)playAllAction:(id)sender {
	[databaseS playAllSongs:self.myId artist:self.myArtist];
}

- (IBAction)shuffleAction:(id)sender {
	[databaseS shuffleAllSongs:self.myId artist:self.myArtist];
}

- (IBAction)nowPlayingAction:(id)sender {
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
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
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [cell updateWithModel:[self.dataModel albumForTableViewRow:indexPath.row]];
    } else {
        // Song
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = NO;
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell updateWithModel:[self.dataModel songForTableViewRow:indexPath.row]];
    }
    return cell;
}

// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row < self.dataModel.albumsCount ? 60.0 : 50.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
	if (viewObjectsS.isCellEnabled) {
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
	} else {
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
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
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
	
    if (self.dataModel.songsCount == 0 && self.dataModel.albumsCount == 0) {
		[self.tableView removeBottomShadow];
    }
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView.isDragging)  {
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.isReloading)  {
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.isReloading) {
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (scrollView.contentOffset.y <= - 65.0f && !self.isReloading) {
		self.isReloading = YES;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
		[self.dataModel startLoad];
		[self.refreshHeaderView setState:EGOOPullRefreshLoading];
        
        [UIView animateWithDuration:0.2 animations:^{
            self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
        }];
	}
}

- (void)dataSourceDidFinishLoadingNewData{
	self.isReloading = NO;
	
    [UIView animateWithDuration:0.3 animations:^{
        [self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
    }];

	[self.refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end
