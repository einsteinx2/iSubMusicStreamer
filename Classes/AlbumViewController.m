//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "AllSongsUITableViewCell.h"
#import "EGORefreshTableHeaderView.h"
#import "ModalAlbumArtViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface AlbumViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
- (void)addHeaderAndIndex;
@end


@implementation AlbumViewController
@synthesize myId, myArtist, myAlbum;
@synthesize sectionInfo;
@synthesize dataModel;
@synthesize playAllShuffleAllView;
@synthesize albumInfoView, albumInfoArtHolderView, albumInfoArtView, albumInfoAlbumLabel, albumInfoArtistLabel, albumInfoDurationLabel, albumInfoLabelHolderView, albumInfoTrackCountLabel, albumInfoArtReflection;

@synthesize isReloading, refreshHeaderView;

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark Lifecycle

- (AlbumViewController *)initWithArtist:(ISMSArtist *)anArtist orAlbum:(ISMSAlbum *)anAlbum
{
	if (anArtist == nil && anAlbum == nil)
	{
		return nil;
	}
	
	self = [super initWithNibName:@"AlbumViewController" bundle:nil];
	if (self != nil)
	{
		self.sectionInfo = nil;
		
		if (anArtist != nil)
		{
			self.title = anArtist.name;
			self.myId = anArtist.artistId;
			self.myArtist = anArtist;
			self.myAlbum = nil;
		}
		else
		{
			self.title = anAlbum.title;
			self.myId = anAlbum.albumId;
			self.myArtist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			self.myAlbum = anAlbum;
		}
		
		self.dataModel = [[SUSSubFolderDAO alloc] initWithDelegate:self andId:self.myId andArtist:self.myArtist];
		
        if (dataModel.hasLoaded)
        {
            [self.tableView reloadData];
            [self addHeaderAndIndex];
        }
        else
        {
            [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
            [dataModel startLoad];
        }
	}
	
	return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
    if (IS_IOS7())
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
	
	albumInfoArtView.delegate = self;
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		
	// Add the pull to refresh view
	self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	self.refreshHeaderView.backgroundColor = [UIColor whiteColor];
	[self.tableView addSubview:self.refreshHeaderView];
	
    
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createReflection) name:@"createReflection"  object:nil];
}

- (void)reloadData
{
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[self.tableView reloadData];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:ISMSNotification_SongPlaybackStarted object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self.dataModel cancelLoad];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];	
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	albumInfoArtView.delegate = nil;
	dataModel.delegate = nil;
}

#pragma mark Loading

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[self dataSourceDidFinishLoadingNewData];
	[viewObjectsS hideLoadingScreen];
}

- (void)createReflection
{
	albumInfoArtReflection.image = [albumInfoArtView reflectedImageWithHeight:albumInfoArtReflection.height];
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView
{
	// Make sure to set the reflection again once the art loads
	[self createReflection];
}

- (void)addHeaderAndIndex
{
	if (dataModel.songsCount == 0 && dataModel.albumsCount == 0)
	{
		self.tableView.tableHeaderView = nil;
	}
	else if (dataModel.songsCount > 0)
	{
		if (!self.tableView.tableHeaderView)
		{
			CGFloat headerHeight = albumInfoView.height + playAllShuffleAllView.height;
			CGRect headerFrame = CGRectMake(0., 0., 320, headerHeight);
			UIView *headerView = [[UIView alloc] initWithFrame:headerFrame];
			
			albumInfoArtView.isLarge = YES;
			
			[headerView addSubview:albumInfoView];
			
			playAllShuffleAllView.y = albumInfoView.height;
			[headerView addSubview:playAllShuffleAllView];
			
			self.tableView.tableHeaderView = headerView;
		}
		
		if (!self.myAlbum)
		{
			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
			ISMSSong *aSong = [self.dataModel songForTableViewRow:self.dataModel.albumsCount];
			anAlbum.title = aSong.album;
			anAlbum.artistName = aSong.artist;
			anAlbum.coverArtId = aSong.coverArtId;
			self.myAlbum = anAlbum;
		}
		
		albumInfoArtView.coverArtId = myAlbum.coverArtId;
		albumInfoArtistLabel.text = myAlbum.artistName;
		albumInfoAlbumLabel.text = myAlbum.title;
		
		albumInfoDurationLabel.text = [NSString formatTime:dataModel.folderLength];
		albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%lu Tracks", (unsigned long)dataModel.songsCount];
		if (dataModel.songsCount == 1)
			albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%lu Track", (unsigned long)dataModel.songsCount];
		
		// Create reflection
		[self createReflection];
		
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
	else
	{
		self.tableView.tableHeaderView = playAllShuffleAllView;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
	
	self.sectionInfo = dataModel.sectionInfo;
	if (sectionInfo)
		[self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)expandCoverArt:(id)sender
{
	if(myAlbum.coverArtId)
	{		
		ModalAlbumArtViewController *largeArt = nil;
		largeArt = [[ModalAlbumArtViewController alloc] initWithAlbum:myAlbum 
													   numberOfTracks:dataModel.songsCount 
														  albumLength:dataModel.folderLength];
		if (IS_IPAD())
			[appDelegateS.ipadRootViewController presentViewController:largeArt animated:YES completion:nil];
		else
			[self presentViewController:largeArt animated:YES completion:nil];
	}
}

- (IBAction)playAllAction:(id)sender
{
	[databaseS playAllSongs:myId artist:myArtist];
}

- (IBAction)shuffleAction:(id)sender
{
	[databaseS shuffleAllSongs:myId artist:myArtist];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	for (int i = 0; i < [sectionInfo count]; i++)
	{
		[indexes addObject:[[sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	NSUInteger row = [[[sectionInfo objectAtIndexSafe:index] objectAtIndexSafe:1] intValue];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return dataModel.totalCount;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	// Set up the cell...
	if (indexPath.row < dataModel.albumsCount)
	{
		static NSString *cellIdentifier = @"AlbumCell";
		AlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		
        ISMSAlbum *anAlbum = [self.dataModel albumForTableViewRow:indexPath.row];
        
        cell.myId = anAlbum.albumId;
		cell.myArtist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		if (sectionInfo)
			cell.isIndexShowing = YES;
		
		cell.coverArtView.coverArtId = anAlbum.coverArtId;
		
		[cell.albumNameLabel setText:anAlbum.title];
        
		// Setup cell backgrond color
        cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"SongCell";
		SongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[SongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		cell.indexPath = indexPath;
        
        ISMSSong *aSong = [self.dataModel songForTableViewRow:indexPath.row];
		//DLog(@"aSong: %@", aSong);
		        
		cell.mySong = aSong;
		
		if (aSong.isCurrentPlayingSong)
		{
			cell.nowPlayingImageView.hidden = NO;
			cell.trackNumberLabel.hidden = YES;
		}
		else 
		{
			cell.nowPlayingImageView.hidden = YES;
			cell.trackNumberLabel.hidden = NO;
			
			if ( [aSong.track intValue] != 0 )
				cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
			else
				cell.trackNumberLabel.text = @"";
		}
		
		//DLog(@"aSong.title: %@", aSong.title);
		cell.songNameLabel.text = aSong.title;
		
		if ( aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if ( aSong.duration )
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
        if (aSong.isFullyCached)
        {
            cell.backgroundView = [[UIView alloc] init];
            cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
        }
        else
        {
            cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
        }
		
		return cell;
	}
}

// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row < dataModel.albumsCount)
		return 60.0;
	else
		return 50.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (indexPath.row < dataModel.albumsCount)
		{
            ISMSAlbum *anAlbum = [dataModel albumForTableViewRow:indexPath.row];
            			
			AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];	
			[self pushViewControllerCustom:albumViewController];
		}
		else
		{
            ISMSSong *playedSong = [self.dataModel playSongAtTableViewRow:indexPath.row];
            
            if (!playedSong.isVideo)
                [self showPlayer];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
	
	if (self.dataModel.songsCount == 0 && self.dataModel.albumsCount == 0)
		[self.tableView removeBottomShadow];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.isReloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.isReloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !self.isReloading) 
	{
		self.isReloading = YES;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
		[self.dataModel startLoad];
		[self.refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	self.isReloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

