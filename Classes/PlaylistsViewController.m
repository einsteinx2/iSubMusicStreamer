//
//  PlaylistsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistsViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "PlaylistsUITableViewCell.h"
#import "CurrentPlaylistSongUITableViewCell.h"
#import "LocalPlaylistsUITableViewCell.h"
#import "PlaylistSongsViewController.h"
#import "StoreViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface PlaylistsViewController (Private)

- (void)addNoPlaylistsScreen;

@end


@implementation PlaylistsViewController

@synthesize request;
@synthesize serverPlaylistsDataModel;
@synthesize currentPlaylistCount;
@synthesize headerView, segmentedControl, noPlaylistsScreen, isNoPlaylistsScreenShowing, savePlaylistLabel, playlistCountLabel, savePlaylistLocal, savePlaylistButton, deleteSongsLabel, editPlaylistLabel, editPlaylistButton, isPlaylistSaveEditShowing, connectionQueue, receivedData, connection;

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD() && isNoPlaylistsScreenShowing)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:duration];
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, -23.0);
		}
		else
		{
			self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, 110.0);
		}
		[UIView commitAnimations];
	}
}

#pragma mark - Lifecycle

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewWillAppear:) name:ISMSNotification_StorePurchaseComplete object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxSongInfo) name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassInitialized object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassFreed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"updateCurrentPlaylistCount" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_StorePurchaseComplete object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistSongsQueued object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxSongInfo object:nil];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
		
	self.serverPlaylistsDataModel = [[SUSServerPlaylistsDAO alloc] initWithDelegate:self];
	
	self.isNoPlaylistsScreenShowing = NO;
	self.isPlaylistSaveEditShowing = NO;
	self.savePlaylistLocal = NO;
	
	self.receivedData = nil;
	
	viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
	
    self.title = @"Playlists";
	
	if (settingsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)];
	
	// Setup segmented control in the header view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	if (settingsS.isOfflineMode)
		self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Current", @"Offline Playlists"]];
	else
		self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Current", @"Local", @"Server"]];
	
	self.segmentedControl.frame = CGRectMake(5, 5, 310, 36);
	self.segmentedControl.selectedSegmentIndex = 0;
	self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (IS_IOS7())
        self.segmentedControl.tintColor = ISMSHeaderColor;
	else
        self.segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	[self.headerView addSubview:self.segmentedControl];
	
	self.tableView.tableHeaderView = self.headerView;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	
	self.connectionQueue = [[EX2SimpleConnectionQueue alloc] init];
	self.connectionQueue.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
		
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	
	if (settingsS.isPlaylistUnlocked)
	{
		// Reload the data in case it changed
		self.tableView.tableHeaderView.hidden = NO;
		[self segmentAction:nil];
	}
	else
	{
		self.tableView.tableHeaderView.hidden = YES;
		//[self performSelector:@selector(addNoPlaylistsScreen) withObject:nil afterDelay:0.1];
		[self addNoPlaylistsScreen];
	}
	
	[Flurry logEvent:@"PlaylistsTab"];

	[self registerForNotifications];
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxGetInfo];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self unregisterForNotifications];
	
	if (self.tableView.editing)
	{
		// Clear the edit stuff if they switch tabs in the middle of editing
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


#pragma mark - Button Handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark -

- (void)jukeboxSongInfo
{
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
	[self selectRow];
}

- (void)songsQueued
{
	[self updateCurrentPlaylistCount];
	[self.tableView reloadData];
}

- (void)updateCurrentPlaylistCount
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		self.currentPlaylistCount = [playlistS count];

		if (self.currentPlaylistCount == 1)
			self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
		else 
			self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
	}
}


- (void)removeEditControls
{
	// Clear the edit stuff if they switch tabs in the middle of editing
	if (self.tableView.editing)
	{
		viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
		self.tableView.editing = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
	}
}


- (void)removeSaveEditButtons
{
	// Remove the save and edit buttons if showing
	if (self.isPlaylistSaveEditShowing == YES)
	{
		self.headerView.frame = CGRectMake(0, 0, 320, 44);
		[self.savePlaylistLabel removeFromSuperview];
		[self.playlistCountLabel removeFromSuperview];
		[self.savePlaylistButton removeFromSuperview];
		[self.editPlaylistLabel removeFromSuperview];
		[self.editPlaylistButton removeFromSuperview];
		[self.deleteSongsLabel removeFromSuperview];
		self.isPlaylistSaveEditShowing = NO;
		self.tableView.tableHeaderView = self.headerView;
	}
}


- (void)addSaveEditButtons
{
	if (self.isPlaylistSaveEditShowing == NO)
	{
		// Modify the header view to include the save and edit buttons
		self.isPlaylistSaveEditShowing = YES;
		self.headerView.frame = CGRectMake(0, 0, 320, 95);
		
		int y = 45;
		
		self.savePlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 227, 34)];
		self.savePlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
		self.savePlaylistLabel.textColor = [UIColor whiteColor];
		self.savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
		self.savePlaylistLabel.font = ISMSBoldFont(22);
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			self.savePlaylistLabel.text = @"Save Playlist";
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			self.savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
			if (localPlaylistsCount == 1)
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 2)
		{
			self.savePlaylistLabel.frame = CGRectMake(0, y, 227, 50);
			NSUInteger serverPlaylistsCount = [self.serverPlaylistsDataModel.serverPlaylists count];
			if (serverPlaylistsCount == 1)
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
			
		}
		[self.headerView addSubview:self.savePlaylistLabel];
		
		self.playlistCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 33, 227, 14)];
		self.playlistCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.playlistCountLabel.backgroundColor = [UIColor clearColor];
		self.playlistCountLabel.textColor = [UIColor whiteColor];
		self.playlistCountLabel.textAlignment = NSTextAlignmentCenter;
		self.playlistCountLabel.font = ISMSBoldFont(12);
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			if (self.currentPlaylistCount == 1)
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
		}
		[self.headerView addSubview:self.playlistCountLabel];
		
		self.savePlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.savePlaylistButton.frame = CGRectMake(0, y, 232, 40);
		self.savePlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		[self.savePlaylistButton addTarget:self action:@selector(savePlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.savePlaylistButton];
		
		self.editPlaylistLabel = [[UILabel alloc] initWithFrame:CGRectMake(232, y, 88, 50)];
		self.editPlaylistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
		self.editPlaylistLabel.textColor = [UIColor whiteColor];
		self.editPlaylistLabel.textAlignment = NSTextAlignmentCenter;
		self.editPlaylistLabel.font = ISMSBoldFont(22);
		self.editPlaylistLabel.text = @"Edit";
		[self.headerView addSubview:self.editPlaylistLabel];
		
		self.editPlaylistButton = [UIButton buttonWithType:UIButtonTypeCustom];
		self.editPlaylistButton.frame = CGRectMake(232, y, 88, 40);
		self.editPlaylistButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		[self.editPlaylistButton addTarget:self action:@selector(editPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
		[self.headerView addSubview:self.editPlaylistButton];	
		
		self.deleteSongsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, y, 232, 50)];
		self.deleteSongsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
		self.deleteSongsLabel.textColor = [UIColor whiteColor];
		self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
		self.deleteSongsLabel.font = ISMSBoldFont(22);
		self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
		self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			self.deleteSongsLabel.text = @"Remove # Songs";
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			self.deleteSongsLabel.text = @"Remove # Playlists";
		}
		self.deleteSongsLabel.hidden = YES;
		[self.headerView addSubview:self.deleteSongsLabel];
		
		self.tableView.tableHeaderView = self.headerView;
	}
	else
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			if (self.currentPlaylistCount == 1)
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
			else 
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
			if (localPlaylistsCount == 1)
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 2)
		{
			NSUInteger serverPlaylistsCount = [self.serverPlaylistsDataModel.serverPlaylists count];
			if (serverPlaylistsCount == 1)
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
			else 
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
			
		}
	}
}

- (void)removeNoPlaylistsScreen
{
	// Remove the no playlists overlay screen if it's showing
	if (self.isNoPlaylistsScreenShowing)
	{
		[self.noPlaylistsScreen removeFromSuperview];
		self.isNoPlaylistsScreenShowing = NO;
	}
}

- (void)addNoPlaylistsScreen
{
	[self removeNoPlaylistsScreen];
	
	self.isNoPlaylistsScreenShowing = YES;
	self.noPlaylistsScreen = [[UIImageView alloc] init];
	self.noPlaylistsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.noPlaylistsScreen.frame = CGRectMake(40, 100, 240, 180);
	self.noPlaylistsScreen.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
	self.noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
	self.noPlaylistsScreen.alpha = .80;
	self.noPlaylistsScreen.userInteractionEnabled = YES;
	
	UILabel *textLabel = [[UILabel alloc] init];
	textLabel.backgroundColor = [UIColor clearColor];
	textLabel.textColor = [UIColor whiteColor];
	textLabel.font = ISMSBoldFont(30);
	textLabel.textAlignment = NSTextAlignmentCenter;
	textLabel.numberOfLines = 0;
	if (settingsS.isPlaylistUnlocked)
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			textLabel.text = @"No Songs\nQueued";
			textLabel.frame = CGRectMake(20, 0, 200, 100);
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1 || self.segmentedControl.selectedSegmentIndex == 2)
		{
			textLabel.text = @"No Playlists\nFound";
			textLabel.frame = CGRectMake(20, 20, 200, 140);
		}
	}
	else
	{
		textLabel.text = @"Playlists\nLocked";
		textLabel.frame = CGRectMake(20, 0, 200, 100);
	}
	[self.noPlaylistsScreen addSubview:textLabel];
	
	UILabel *textLabel2 = [[UILabel alloc] init];
	textLabel2.backgroundColor = [UIColor clearColor];
	textLabel2.textColor = [UIColor whiteColor];
	textLabel2.font = ISMSBoldFont(14);
	textLabel2.textAlignment = NSTextAlignmentCenter;
	textLabel2.numberOfLines = 0;
	if (settingsS.isPlaylistUnlocked)
	{
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			
			textLabel2.text = @"Swipe to the right on any song, album, or artist to bring up the Queue button";
			textLabel2.frame = CGRectMake(20, 100, 200, 60);
		}
	}
	else
	{
		textLabel2.text = @"Tap to purchase the ability to view, create, and manage playlists";
		textLabel2.frame = CGRectMake(20, 100, 200, 60);
	}
	[self.noPlaylistsScreen addSubview:textLabel2];
	
	if (!settingsS.isPlaylistUnlocked)
	{
		UIButton *storeLauncher = [UIButton buttonWithType:UIButtonTypeCustom];
		storeLauncher.frame = CGRectMake(0, 0, self.noPlaylistsScreen.frame.size.width, self.noPlaylistsScreen.frame.size.height);
		[storeLauncher addTarget:self action:@selector(showStore) forControlEvents:UIControlEventTouchUpInside];
		[self.noPlaylistsScreen addSubview:storeLauncher];
	}
	
	[self.view addSubview:self.noPlaylistsScreen];
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			//noPlaylistsScreen.transform = CGAffineTransformScale(noPlaylistsScreen.transform, 0.75, 0.75);
			self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, 23.0);
		}
	}
}

- (void)showStore
{
	StoreViewController *store = [[StoreViewController alloc] init];
	[self pushViewControllerCustom:store];
	//[self.navigationController pushViewController:store animated:YES];
}

- (void)segmentAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		viewObjectsS.isLocalPlaylist = YES;
		
		// Get the current playlist count
		self.currentPlaylistCount = [playlistS count];

		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		if (self.currentPlaylistCount > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// TODO: do this for iPad as well, different minScrollRow values
		NSUInteger minScrollRow = 5;
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			minScrollRow = 2;
		
		UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
		if (playlistS.currentIndex > minScrollRow)
			scrollPosition = UITableViewScrollPositionMiddle;
		
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:scrollPosition];
		}
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (self.currentPlaylistCount == 0)
		{
			[self addNoPlaylistsScreen];
		}
		
		// If the list is empty remove the Save/Edit bar
		if (self.currentPlaylistCount == 0)
		{
			[self removeSaveEditButtons];
		}
	}
	else if(self.segmentedControl.selectedSegmentIndex == 1)
	{
		viewObjectsS.isLocalPlaylist = YES;
		
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
		
		if (localPlaylistsCount > 0)
		{
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (localPlaylistsCount == 0)
		{
			[self addNoPlaylistsScreen];
		}
	}
	else if(self.segmentedControl.selectedSegmentIndex == 2)
	{
		viewObjectsS.isLocalPlaylist = NO;
		
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];

		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
        [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
        [self.serverPlaylistsDataModel startLoad];
	}
}

- (void)editPlaylistAction:(id)sender
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (!self.tableView.editing)
		{
			[self.tableView reloadData];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			self.editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
			
			[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
			self.editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
			if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
			{
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
			}
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1 ||
			 self.segmentedControl.selectedSegmentIndex == 2)
	{
		if (!self.tableView.editing)
		{
			[self.tableView reloadData];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(showDeleteButton) name:@"showDeleteButton" object: nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(hideDeleteButton) name:@"hideDeleteButton" object: nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:YES animated:YES];
			self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
			self.editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
			
			[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(showDeleteToggle) userInfo:nil repeats:NO];
		}
		else 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"showDeleteButton" object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideDeleteButton" object:nil];
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithCapacity:1];
			[self.tableView setEditing:NO animated:YES];
			[self hideDeleteButton];
			self.editPlaylistLabel.backgroundColor = [UIColor clearColor];
			self.editPlaylistLabel.text = @"Edit";
			
			// Reload the table to correct the numbers
			[self.tableView reloadData];
		}
	}
}

- (void)showDeleteButton
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if ([viewObjectsS.multiDeleteList count] == 0)
		{
			self.deleteSongsLabel.text = @"Select All";
		}
		else if ([viewObjectsS.multiDeleteList count] == 1)
		{
			self.deleteSongsLabel.text = @"Remove 1 Song  ";
		}
		else
		{
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1 ||
			 self.segmentedControl.selectedSegmentIndex == 2)
	{
		if ([viewObjectsS.multiDeleteList count] == 0)
		{
			self.deleteSongsLabel.text = @"Select All";
		}
		else if ([viewObjectsS.multiDeleteList count] == 1)
		{
			self.deleteSongsLabel.text = @"Remove 1 Playlist";
		}
		else
		{
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)[viewObjectsS.multiDeleteList count]];
		}
	}
	
	self.savePlaylistLabel.hidden = YES;
	self.playlistCountLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}
		
- (void) hideDeleteButton
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if ([viewObjectsS.multiDeleteList count] == 0)
		{
			if (!self.tableView.editing)
			{
				self.savePlaylistLabel.hidden = NO;
				self.playlistCountLabel.hidden = NO;
				self.deleteSongsLabel.hidden = YES;
			}
			else
			{
				self.deleteSongsLabel.text = @"Clear Playlist";
			}
		}
		else if ([viewObjectsS.multiDeleteList count] == 1)
		{
			self.deleteSongsLabel.text = @"Remove 1 Song  ";
		}
		else 
		{
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)[viewObjectsS.multiDeleteList count]];
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1 ||
			 self.segmentedControl.selectedSegmentIndex == 2)
	{
		if ([viewObjectsS.multiDeleteList count] == 0)
		{
			if (!self.tableView.editing)
			{
				self.savePlaylistLabel.hidden = NO;
				self.playlistCountLabel.hidden = NO;
				self.deleteSongsLabel.hidden = YES;
			}
			else
			{
				self.deleteSongsLabel.text = @"Clear Playlists";
			}
		}
		else if ([viewObjectsS.multiDeleteList count] == 1)
		{
			self.deleteSongsLabel.text = @"Remove 1 Playlist";
		}
		else 
		{
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)[viewObjectsS.multiDeleteList count]];
		}
	}
}

- (void) showDeleteToggle
{
	// Show the delete toggle for already visible cells
	for (id cell in self.tableView.visibleCells) 
	{
		[[cell deleteToggleImage] setHidden:NO];
	}
}

- (void)uploadPlaylist:(NSString*)name
{	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
	
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
	NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
	NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
	NSString *table = playlistS.isShuffle ? shufTable : currTable;
	
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	 {
		 for (int i = 0; i < self.currentPlaylistCount; i++)
		 {
			 @autoreleasepool 
			 {
				 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
				 [songIds addObject:n2N(aSong.songId)];
			 }
		 }
	 }];
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];

	self.request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
	
	self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

- (void)deleteAction
{	
	[self unregisterForNotifications];
	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		[playlistS deleteSongs:viewObjectsS.multiDeleteList];
		[self updateCurrentPlaylistCount];
		
		[self.tableView reloadData];
		
		/*// Create indexPaths from multiDeleteList and delete the rows in the table view
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjectsS.multiDeleteList)
		{
			@autoreleasepool 
			{
				[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
			}
		}
		
		@try
		{
			[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
		}
		@catch (NSException *exception) 
		{
		//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}*/
		
		[self editPlaylistAction:nil];
		[self segmentAction:nil];
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1)
	{
		// Sort the multiDeleteList to make sure it's accending
		[viewObjectsS.multiDeleteList sortUsingSelector:@selector(compare:)];
		
		[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE localPlaylistsTemp"];
			[db executeUpdate:@"CREATE TABLE localPlaylistsTemp(playlist TEXT, md5 TEXT)"];
			for (NSNumber *index in [viewObjectsS.multiDeleteList reverseObjectEnumerator])
			{
				@autoreleasepool 
				{
					NSInteger rowId = [index integerValue] + 1;
					NSString *md5 = [db stringForQuery:[NSString stringWithFormat:@"SELECT md5 FROM localPlaylists WHERE ROWID = %li", (long)rowId]];
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", md5]];
					[db executeUpdate:@"DELETE FROM localPlaylists WHERE md5 = ?", md5];
				}
			}
			[db executeUpdate:@"INSERT INTO localPlaylistsTemp SELECT * FROM localPlaylists"];
			[db executeUpdate:@"DROP TABLE localPlaylists"];
			[db executeUpdate:@"ALTER TABLE localPlaylistsTemp RENAME TO localPlaylists"];
		}];
		
		[self.tableView reloadData];
		
		/*// Create indexPaths from multiDeleteList and delete the rows from the tableView
		NSMutableArray *indexes = [[NSMutableArray alloc] init];
		for (NSNumber *index in viewObjectsS.multiDeleteList)
		{
			[indexes addObject:[NSIndexPath indexPathForRow:[index integerValue] inSection:0]];
		}
	
		@try
		{
			[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:YES];
		}
		@catch (NSException *exception) 
		{
		//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}*/
		
		
		[self editPlaylistAction:nil];
		[self segmentAction:nil];
	}
	
	[viewObjectsS hideLoadingScreen];
	
	[self registerForNotifications];	
}

- (void)savePlaylistAction:(id)sender
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (self.deleteSongsLabel.hidden == YES)
		{
			if (!self.tableView.editing)
			{
				if (settingsS.isOfflineMode)
				{
					[self showSavePlaylistTextBoxAlert];
				}
				else
				{
					self.savePlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
					self.playlistCountLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
					
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Local or Server?" 
																		  message:@"Would you like to save this playlist to your device or to your Subsonic server?" 
																		 delegate:self 
																cancelButtonTitle:nil
																otherButtonTitles:@"Local", @"Server", nil];
					[myAlertView show];
				}
			}
		}
		else 
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				for (int i = 0; i < self.currentPlaylistCount; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(deleteAction) withObject:nil afterDelay:0.05];
			}
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1)
	{
		if (self.deleteSongsLabel.hidden == NO)
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
				for (int i = 0; i < count; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self showDeleteButton];
			}
			else
			{
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(deleteAction) withObject:nil afterDelay:0.05];
			}
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 2)
	{
		if (self.deleteSongsLabel.hidden == NO)
		{
			if ([viewObjectsS.multiDeleteList count] == 0)
			{
				// Select all the rows
				NSUInteger count = [self.serverPlaylistsDataModel.serverPlaylists count];
				for (int i = 0; i < count; i++)
				{
					[viewObjectsS.multiDeleteList addObject:@(i)];
				}
				[self.tableView reloadData];
				[self showDeleteButton];
			}
			else
			{
				self.tableView.scrollEnabled = NO;
				[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
				
				for (NSNumber *index in viewObjectsS.multiDeleteList)
				{
                    NSString *playlistId = [[self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:[index intValue]] playlistId];
                    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(playlistId) forKey:@"id"];
                    DLog(@"parameters: %@", parameters);
                    NSMutableURLRequest *aRequest = [NSMutableURLRequest requestWithSUSAction:@"deletePlaylist" parameters:parameters];
                    
					self.connection = [[NSURLConnection alloc] initWithRequest:aRequest delegate:self startImmediately:NO];
					if (self.connection)
					{
						[self.connectionQueue registerConnection:self.connection];
						[self.connectionQueue startQueue];
					} 
					else 
					{
					//DLog(@"There was an error deleting a server playlist, could not create network request");
					}
				}
			}
		}
	}
}

- (void)connectionQueueDidFinish:(id)connectionQueue
{
	[viewObjectsS hideLoadingScreen];
	self.tableView.scrollEnabled = YES;
	[self editPlaylistAction:nil];
	[self segmentAction:nil];
}

- (void)cancelLoad
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		[self.connection cancel];
	}
	else
	{
		if (self.connectionQueue.isRunning)
		{
			[self.connectionQueue clearQueue];
			
			[self connectionQueueDidFinish:self.connectionQueue];
		}
		else
		{
			[self.serverPlaylistsDataModel cancelLoad];
			[viewObjectsS hideLoadingScreen];
		}
	}
}

- (void)showSavePlaylistTextBoxAlert
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Playlist Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [myAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if ([alertView.title isEqualToString:@"Local or Server?"])
	{
		if (buttonIndex == 0)
		{
			self.savePlaylistLocal = YES;
		}
		else if (buttonIndex == 1)
		{
			self.savePlaylistLocal = NO;
		}
		else if (buttonIndex == 2)
		{
			return;
		}
		
		[self showSavePlaylistTextBoxAlert];
	}
    else if([alertView.title isEqualToString:@"Playlist Name:"])
	{
		NSString *text = [alertView textFieldAtIndex:0].text;
		if(buttonIndex == 1)
		{
			if (self.savePlaylistLocal || settingsS.isOfflineMode)
			{
				// Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
				NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", [text md5]];
				if (!test)
				{
					NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
					NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
					NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
					NSString *table = playlistS.isShuffle ? shufTable : currTable;
					
					[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", text, [text md5]];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
						
						[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylist"];
						//[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:@"%@/%@currentPlaylist.db", databaseS.databaseFolderPath, [settingsS.urlString md5]], @"currentPlaylistDb"];
						if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
						
						[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
						[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
					}];
				}
				else
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				}
			}
			else
			{
				NSString *tableName = [NSString stringWithFormat:@"splaylist%@", [text md5]];
				if ([databaseS.localPlaylistsDbQueue tableExists:tableName])
				{
					// If it exists, ask to overwrite
					UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Overwrite?" message:@"There is already a playlist with this name. Would you like to overwrite it?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                    [myAlertView ex2SetCustomObject:text forKey:@"name"];
					[myAlertView show];
				}
				else 
				{
					[self uploadPlaylist:text];
				}
			}
		}
	}
	else if([alertView.title isEqualToString:@"Overwrite?"])
	{
        NSString *text = [alertView ex2CustomObjectForKey:@"name"];
		if(buttonIndex == 1)
		{
			if (self.savePlaylistLocal || settingsS.isOfflineMode)
			{
				NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
				NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
				NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
				NSString *table = playlistS.isShuffle ? shufTable : currTable;
				
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					// If yes, overwrite the playlist
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", [text md5]]];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", [text md5], [ISMSSong standardSongColumnSchema]]];
					
					[db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
					if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
					
					[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", [text md5], table]];
					[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
				}];				
			}
			else
			{
				[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", [text md5]]];
				}];
				
				[self uploadPlaylist:text];
			}
		}
	}
	
	self.savePlaylistLabel.backgroundColor = [UIColor clearColor];
	self.playlistCountLabel.backgroundColor = [UIColor clearColor];
}

- (void)selectRow
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		[self.tableView reloadData];
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
	}
}

#pragma mark - ISMSLoader Delegate

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{    
    [self.tableView reloadData];
    
    // If the list is empty, display the no playlists overlay screen
    if ([self.serverPlaylistsDataModel.serverPlaylists count] == 0 && self.isNoPlaylistsScreenShowing == NO)
    {
		[self addNoPlaylistsScreen];
    }
    else
    {
        // Modify the header view to include the save and edit buttons
        [self addSaveEditButtons];
    }
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (segmentedControl.selectedSegmentIndex == 0)
		[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
		[self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", 
				   (long)[error code],
				   [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlists.\n\nError %li: %@",
				   (long)[error code],
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
	}
	else
	{
		[self.connectionQueue connectionFinished:theConnection];
	}
}	

- (NSURLRequest *)connection: (NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) 
	{
        NSMutableURLRequest *newRequest = [self.request mutableCopy];
        [newRequest setURL:[inRequest URL]];
        return newRequest;
    } 
	else 
	{
        return inRequest;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		[self parseData];
	}
	else
	{
		[self.connectionQueue connectionFinished:theConnection];
	}
	
	self.tableView.scrollEnabled = YES;
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
}

- (void)parseData
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self subsonicErrorCode:nil message:error.description];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:code message:message];
        }
    }
	
	[viewObjectsS hideLoadingScreen];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if (self.segmentedControl.selectedSegmentIndex == 0 && self.currentPlaylistCount > 0)
	{
		if (!self.tableView.editing)
		{
			NSMutableArray *searchIndexes = [[NSMutableArray alloc] init];
			for (int x = 0; x < 20; x++)
			{
				[searchIndexes addObject:@"●"];
			}
			return searchIndexes;
		}
		else
		{
			return nil;
		}
	}
	else 
	{
		return nil;
	}

}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		if (index == 0)
		{
			[tableView scrollRectToVisible:CGRectMake(0, 0, 320, 40) animated:NO];
		}
		else if (index == 19)
		{
			NSInteger row = self.currentPlaylistCount - 1;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
		}
		else 
		{
			NSInteger row = self.currentPlaylistCount / 20 * index;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
			return -1;		
		}
	}
	
	return index - 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{	
	if (segmentedControl.selectedSegmentIndex == 0)
		return self.currentPlaylistCount;
	else if (segmentedControl.selectedSegmentIndex == 1)
		return [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
	else if (segmentedControl.selectedSegmentIndex == 2)
		return self.serverPlaylistsDataModel.serverPlaylists.count;
	
	return 0;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		NSInteger fromRow = fromIndexPath.row + 1;
		NSInteger toRow = toIndexPath.row + 1;
		
		[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
			NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
			NSString *table = playlistS.isShuffle ? shufTable : currTable;
			
		//DLog(@"table: %@", table);
			
			[db executeUpdate:@"DROP TABLE moveTemp"];
			NSString *query = [NSString stringWithFormat:@"CREATE TABLE moveTemp (%@)", [ISMSSong standardSongColumnSchema]];
			[db executeUpdate:query];
			
			if (fromRow < toRow)
			{
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ? AND ROWID <= ?", table], @(fromRow), @(toRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(toRow)];
				
				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
			}
			else
			{
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(toRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID >= ? AND ROWID < ?", table], @(toRow), @(fromRow)];
				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(fromRow)];
				
				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
			}
		}];
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
				
		// Fix the multiDeleteList to reflect the new row positions
		if ([viewObjectsS.multiDeleteList count] > 0)
		{
			NSMutableArray *tempMultiDeleteList = [[NSMutableArray alloc] init];
			int newPosition;
			for (NSNumber *position in viewObjectsS.multiDeleteList)
			{
				if (fromIndexPath.row > toIndexPath.row)
				{
					if ([position intValue] >= toIndexPath.row && [position intValue] <= fromIndexPath.row)
					{
						if ([position intValue] == fromIndexPath.row)
						{
							[tempMultiDeleteList addObject:@(toIndexPath.row)];
						}
						else 
						{
							newPosition = [position intValue] + 1;
							[tempMultiDeleteList addObject:@(newPosition)];
						}
					}
					else
					{
						[tempMultiDeleteList addObject:position];
					}
				}
				else
				{
					if ([position intValue] <= toIndexPath.row && [position intValue] >= fromIndexPath.row)
					{
						if ([position intValue] == fromIndexPath.row)
						{
							[tempMultiDeleteList addObject:@(toIndexPath.row)];
						}
						else 
						{
							newPosition = [position intValue] - 1;
							[tempMultiDeleteList addObject:@(newPosition)];
						}
					}
					else
					{
						[tempMultiDeleteList addObject:position];
					}
				}
			}
			viewObjectsS.multiDeleteList = [NSMutableArray arrayWithArray:tempMultiDeleteList];
		}
		
		// Correct the value of currentPlaylistPosition
		if (fromIndexPath.row == playlistS.currentIndex)
		{
			playlistS.currentIndex = toIndexPath.row;
		}
		else 
		{
			if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex)
			{
				playlistS.currentIndex = playlistS.currentIndex - 1;
			}
			else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex)
			{
				playlistS.currentIndex = playlistS.currentIndex + 1;
			}
		}
		
		// Highlight the current playing song
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount)
		{
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		}
		
		if (!settingsS.isJukeboxEnabled)
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
	}
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
		return YES;
	else if (self.segmentedControl.selectedSegmentIndex == 1)
		return NO; //this will be changed to YES and will be fully editable
	else if (self.segmentedControl.selectedSegmentIndex == 2)
		return NO;
	
	return NO;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		static NSString *cellIdentifier = @"CurrentPlaylistSongCell";
		CurrentPlaylistSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[CurrentPlaylistSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.indexPath = indexPath;
		
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:@(indexPath.row)])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		ISMSSong *aSong = [playlistS songForIndex:indexPath.row];
		
		cell.coverArtView.coverArtId = aSong.coverArtId;
		
		if (indexPath.row == playlistS.currentIndex && (audioEngineS.player.isStarted || (settingsS.isJukeboxEnabled && jukeboxS.jukeboxIsPlaying)))
		{
			cell.nowPlayingImageView.hidden = NO;
			cell.numberLabel.hidden = YES;
		}
		else 
		{
			cell.nowPlayingImageView.hidden = YES;
			cell.numberLabel.hidden = NO;
			cell.numberLabel.text = [NSString stringWithFormat:@"%li", (long)(indexPath.row + 1)];
		}
		
		cell.songNameLabel.text = aSong.title;
		
		if (aSong.album)
			cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
		else
			cell.artistNameLabel.text = aSong.artist;
		
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
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		static NSString *cellIdentifier = @"LocalPlaylistsCell";
		LocalPlaylistsUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[LocalPlaylistsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.indexPath = indexPath;
		
		// Set up the cell...
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:@(indexPath.row)])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.text = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
		cell.md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
		cell.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", cell.md5]];
		if (cell.playlistCount == 1)
		{
			cell.playlistCountLabel.text = @"1 song";
		}
		else
		{
			cell.playlistCountLabel.text = [NSString stringWithFormat:@"%li songs", (long)cell.playlistCount];
		}
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		static NSString *cellIdentifier = @"PlaylistsCell";
		PlaylistsUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[PlaylistsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.indexPath = indexPath;
        cell.serverPlaylist = [self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];
		
		cell.deleteToggleImage.hidden = !self.tableView.editing;
		cell.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
		if ([viewObjectsS.multiDeleteList containsObject:@(indexPath.row)])
		{
			cell.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
		}
		
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.playlistNameLabel.backgroundColor = [UIColor clearColor];
        SUSServerPlaylist *playlist = [self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];        
        cell.playlistNameLabel.text = playlist.playlistName;
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;		
	}
	
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (segmentedControl.selectedSegmentIndex == 0)
		{
            ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
            if (!playedSong.isVideo)
                [self showPlayer];
		}
		else if (segmentedControl.selectedSegmentIndex == 1)
		{
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
			playlistSongsViewController.md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
			[self pushViewControllerCustom:playlistSongsViewController];
		}
		else if (segmentedControl.selectedSegmentIndex == 2)
		{
			PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] initWithNibName:@"PlaylistSongsViewController" bundle:nil];
            SUSServerPlaylist *playlist = [serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];
			playlistSongsViewController.md5 = [playlist.playlistName md5];
            playlistSongsViewController.serverPlaylist = playlist;
			[self pushViewControllerCustom:playlistSongsViewController];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.serverPlaylistsDataModel.delegate = nil;
	self.connectionQueue = nil;
}


@end

