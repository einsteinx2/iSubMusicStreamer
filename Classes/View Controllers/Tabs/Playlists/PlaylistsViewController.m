//
//  PlaylistsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistsViewController.h"
#import "ServerListViewController.h"
#import "PlaylistSongsViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSMutableURLRequest+SUS.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "Flurry.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlayQueueSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "NSError+ISMSError.h"
#import "SUSServerPlaylistsDAO.h"
//#import "ISMSSong+DAO.h"
#import "SUSServerPlaylist.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "ISMSLocalPlaylist.h"

LOG_LEVEL_ISUB_DEFAULT

@interface PlaylistsViewController()
@property (nonatomic, strong) NSURLSession *sharedSession;
@property (nonatomic, strong) SelfSignedCertURLSessionDelegate *sharedSessionDelegate;
@end

@implementation PlaylistsViewController

#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (UIDevice.isPad) return;
        
        if (UIInterfaceOrientationIsPortrait(UIApplication.orientation)) {
            self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, -23.0);
        } else {
            self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, 110.0);
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - Lifecycle

- (void)registerForNotifications {
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_BassInitialized];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_BassFreed];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(selectRow) name:ISMSNotification_CurrentPlaylistShuffleToggled];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateCurrentPlaylistCount) name:@"updateCurrentPlaylistCount"];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(songsQueued) name:ISMSNotification_CurrentPlaylistSongsQueued];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxSongInfo) name:ISMSNotification_JukeboxSongInfo];
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

- (void)recreateSharedSession {
    [self.sharedSession invalidateAndCancel];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    self.sharedSessionDelegate = [[SelfSignedCertURLSessionDelegate alloc] init];
    self.sharedSession = [NSURLSession sessionWithConfiguration:configuration
                                                       delegate:self.sharedSessionDelegate
                                                  delegateQueue:nil];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    [self recreateSharedSession];
		
	self.serverPlaylistsDataModel = [[SUSServerPlaylistsDAO alloc] initWithDelegate:self];
	
	self.isNoPlaylistsScreenShowing = NO;
	self.isPlaylistSaveEditShowing = NO;
	self.savePlaylistLocal = NO;
			
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    self.title = @"Playlists";
	
    if (settingsS.isOfflineMode) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsAction:)];
    }
    
    self.segmentControlContainer = [[UIView alloc] init];
    self.segmentControlContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (settingsS.isOfflineMode) {
		self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Current", @"Offline Playlists"]];
    } else {
		self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Current", @"Local", @"Server"]];
    }
    
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentedControl.selectedSegmentIndex = 0;
	self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
    
    [self.segmentControlContainer addSubview:self.segmentedControl];
    [self.view addSubview:self.segmentControlContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControlContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:7],
        [self.segmentControlContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:5],
        [self.segmentControlContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-5],
        [self.segmentControlContainer.heightAnchor constraintEqualToConstant:36],
        
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.segmentControlContainer.topAnchor],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.segmentControlContainer.leadingAnchor],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.segmentControlContainer.trailingAnchor]
    ]];
	
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableViewTopConstraint = [self.tableView.topAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        self.tableViewTopConstraint,
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
//	self.tableView.tableHeaderView = self.headerView;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
	    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
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
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"music.quarternote.3"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
	
    // Reload the data in case it changed
    self.tableView.tableHeaderView.hidden = NO;
    [self segmentAction:nil];
	
	[Flurry logEvent:@"PlaylistsTab"];

	[self registerForNotifications];
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS getInfo];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[self unregisterForNotifications];
	
	if (self.isEditing) {
		// Clear the edit stuff if they switch tabs in the middle of editing
		self.editing = NO;
	}
}

#pragma mark - Button Handling

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

#pragma mark -

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
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		self.currentPlaylistCount = playlistS.count;

        if (self.currentPlaylistCount == 1) {
			self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
        } else {
			self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
        }
	}
}

- (void)removeEditControls {
	// Clear the edit stuff if they switch tabs in the middle of editing
	if (self.isEditing) {
		self.editing = NO;
	}
}

- (void)removeSaveEditButtons {
    if (!self.isPlaylistSaveEditShowing) return;
    
    self.isPlaylistSaveEditShowing = NO;
    [self.saveEditContainer removeFromSuperview]; self.saveEditContainer = nil;
    [self.savePlaylistLabel removeFromSuperview]; self.savePlaylistLabel = nil;
    [self.playlistCountLabel removeFromSuperview]; self.playlistCountLabel = nil;
    [self.savePlaylistButton removeFromSuperview]; self.savePlaylistButton = nil;
    [self.editPlaylistLabel removeFromSuperview]; self.editPlaylistLabel = nil;
    [self.editPlaylistButton removeFromSuperview]; self.editPlaylistButton = nil;
    [self.deleteSongsLabel removeFromSuperview]; self.deleteSongsLabel = nil;
            
    self.tableView.tableHeaderView = nil;
    
    self.tableViewTopConstraint.constant = 0;
    [self.tableView setNeedsUpdateConstraints];
}


- (void)addSaveEditButtons {    
	if (self.isPlaylistSaveEditShowing == NO) {
		self.isPlaylistSaveEditShowing = YES;
        
        self.saveEditContainer = [[UIView alloc] init];
        self.saveEditContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.saveEditContainer];
        		
        self.savePlaylistLabel = [[UILabel alloc] init];
        self.savePlaylistLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.savePlaylistLabel.textColor = UIColor.labelColor;
		self.savePlaylistLabel.textAlignment = NSTextAlignmentCenter;
		self.savePlaylistLabel.font = [UIFont boldSystemFontOfSize:22];
		if (self.segmentedControl.selectedSegmentIndex == 0) {
			self.savePlaylistLabel.text = @"Save Playlist";
		} else if (self.segmentedControl.selectedSegmentIndex == 1) {
			self.savePlaylistLabel.frame = CGRectMake(0, 0, 227, 50);
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
            if (localPlaylistsCount == 1) {
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
            } else {
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
            }
		} else if (self.segmentedControl.selectedSegmentIndex == 2) {
			self.savePlaylistLabel.frame = CGRectMake(0, 0, 227, 50);
			NSUInteger serverPlaylistsCount = [self.serverPlaylistsDataModel.serverPlaylists count];
            if (serverPlaylistsCount == 1) {
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"1 playlist"];
            } else {
				self.savePlaylistLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
            }
		}
		[self.saveEditContainer addSubview:self.savePlaylistLabel];
		
        self.playlistCountLabel = [[UILabel alloc] init];
        self.playlistCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.playlistCountLabel.textColor = UIColor.labelColor;
		self.playlistCountLabel.textAlignment = NSTextAlignmentCenter;
		self.playlistCountLabel.font = [UIFont boldSystemFontOfSize:12];
		if (self.segmentedControl.selectedSegmentIndex == 0) {
            if (self.currentPlaylistCount == 1) {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
            } else {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
            }
		}
		[self.saveEditContainer addSubview:self.playlistCountLabel];
        
        self.deleteSongsLabel = [[UILabel alloc] init];
        self.deleteSongsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.deleteSongsLabel.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:.5];
        self.deleteSongsLabel.textColor = UIColor.labelColor;
        self.deleteSongsLabel.textAlignment = NSTextAlignmentCenter;
        self.deleteSongsLabel.font = [UIFont boldSystemFontOfSize:22];
        self.deleteSongsLabel.adjustsFontSizeToFitWidth = YES;
        self.deleteSongsLabel.minimumScaleFactor = 12.0 / self.deleteSongsLabel.font.pointSize;
        if (self.segmentedControl.selectedSegmentIndex == 0) {
            self.deleteSongsLabel.text = @"Remove # Songs";
        } else if (self.segmentedControl.selectedSegmentIndex == 1) {
            self.deleteSongsLabel.text = @"Remove # Playlists";
        }
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
            [self.saveEditContainer.topAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor constant:8],
            
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
        
        self.tableViewTopConstraint.constant = 58;
        [self.tableView setNeedsUpdateConstraints];
	} else {
		if (self.segmentedControl.selectedSegmentIndex == 0) {
            if (self.currentPlaylistCount == 1) {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 song"];
            } else {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.currentPlaylistCount];
            }
		} else if (self.segmentedControl.selectedSegmentIndex == 1) {
			NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
            if (localPlaylistsCount == 1) {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
            } else {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)localPlaylistsCount];
            }
		} else if (self.segmentedControl.selectedSegmentIndex == 2) {
			NSUInteger serverPlaylistsCount = [self.serverPlaylistsDataModel.serverPlaylists count];
            if (serverPlaylistsCount == 1) {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"1 playlist"];
            } else {
				self.playlistCountLabel.text = [NSString stringWithFormat:@"%lu playlists", (unsigned long)serverPlaylistsCount];
            }
        }
	}
}

- (void)removeNoPlaylistsScreen {
	// Remove the no playlists overlay screen if it's showing
	if (self.isNoPlaylistsScreenShowing) {
		[self.noPlaylistsScreen removeFromSuperview];
		self.isNoPlaylistsScreenShowing = NO;
	}
}

- (void)addNoPlaylistsScreen {
	[self removeNoPlaylistsScreen];
	
	self.isNoPlaylistsScreenShowing = YES;
	self.noPlaylistsScreen = [[UIImageView alloc] init];
	self.noPlaylistsScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.noPlaylistsScreen.frame = CGRectMake(40, 100, 240, 180);
	self.noPlaylistsScreen.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
	self.noPlaylistsScreen.image = [UIImage imageNamed:@"loading-screen-image"];
	self.noPlaylistsScreen.alpha = .80;
	self.noPlaylistsScreen.userInteractionEnabled = YES;
	
	UILabel *textLabel = [[UILabel alloc] init];
	textLabel.backgroundColor = [UIColor clearColor];
	textLabel.textColor = [UIColor whiteColor];
	textLabel.font = [UIFont boldSystemFontOfSize:30];
	textLabel.textAlignment = NSTextAlignmentCenter;
	textLabel.numberOfLines = 0;
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        textLabel.text = @"No Songs\nQueued";
        textLabel.frame = CGRectMake(20, 0, 200, 100);
    } else if (self.segmentedControl.selectedSegmentIndex == 1 || self.segmentedControl.selectedSegmentIndex == 2) {
        textLabel.text = @"No Playlists\nFound";
        textLabel.frame = CGRectMake(20, 20, 200, 140);
    }
	[self.noPlaylistsScreen addSubview:textLabel];
	
	UILabel *textLabel2 = [[UILabel alloc] init];
	textLabel2.backgroundColor = [UIColor clearColor];
	textLabel2.textColor = [UIColor whiteColor];
    textLabel2.font = [UIFont boldSystemFontOfSize:14];
	textLabel2.textAlignment = NSTextAlignmentCenter;
	textLabel2.numberOfLines = 0;
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        textLabel2.text = @"Swipe to the right on any song, album, or artist to bring up the Queue button";
        textLabel2.frame = CGRectMake(20, 100, 200, 60);
    }
	[self.noPlaylistsScreen addSubview:textLabel2];
	
	[self.view addSubview:self.noPlaylistsScreen];
	
	if (!UIDevice.isPad) {
		if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
			//noPlaylistsScreen.transform = CGAffineTransformScale(noPlaylistsScreen.transform, 0.75, 0.75);
			self.noPlaylistsScreen.transform = CGAffineTransformTranslate(self.noPlaylistsScreen.transform, 0.0, 23.0);
		}
	}
}

- (void)segmentAction:(id)sender {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		// Get the current playlist count
		self.currentPlaylistCount = [playlistS count];

		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		if (self.currentPlaylistCount > 0) {
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// TODO: do this for iPad as well, different minScrollRow values
		NSUInteger minScrollRow = 5;
        if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
			minScrollRow = 2;
        }
		
		UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
        if (playlistS.currentIndex > minScrollRow) {
			scrollPosition = UITableViewScrollPositionTop;
        }
		
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:scrollPosition];
		}
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (self.currentPlaylistCount == 0) {
			[self addNoPlaylistsScreen];
		}
		
		// If the list is empty remove the Save/Edit bar
		if (self.currentPlaylistCount == 0) {
			[self removeSaveEditButtons];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
		// Clear the edit stuff if they switch tabs in the middle of editing
		[self removeEditControls];
		
		// Remove the save and edit buttons if showing
		[self removeSaveEditButtons];
		
		NSUInteger localPlaylistsCount = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
		
		if (localPlaylistsCount > 0) {
			// Modify the header view to include the save and edit buttons
			[self addSaveEditButtons];
		}
		
		// Reload the table data
		[self.tableView reloadData];
		
		// Remove the no playlists overlay screen if it's showing
		[self removeNoPlaylistsScreen];
		
		// If the list is empty, display the no playlists overlay screen
		if (localPlaylistsCount == 0) {
			[self addNoPlaylistsScreen];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 2) {		
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

- (void)editPlaylistAction:(id)sender {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
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
            [self setEditing:YES animated:YES];
			self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
            self.editPlaylistLabel.textColor = UIColor.labelColor;
			self.editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
		}
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1 || self.segmentedControl.selectedSegmentIndex == 2) {
		if (self.isEditing) {
            [self setEditing:NO animated:YES];
            [self hideDeleteButton];
            self.editPlaylistLabel.backgroundColor = UIColor.clearColor;
            self.editPlaylistLabel.textColor = UIColor.systemBlueColor;
            
            // Reload the table to correct the numbers
            [self.tableView reloadData];
        } else {
            [self setEditing:YES animated:YES];
			self.editPlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
            self.editPlaylistLabel.textColor = UIColor.labelColor;
			self.editPlaylistLabel.text = @"Done";
			[self showDeleteButton];
		}
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

- (void)showDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (selectedRowsCount == 0) {
			self.deleteSongsLabel.text = @"Select All";
		} else if (selectedRowsCount == 1) {
			self.deleteSongsLabel.text = @"Remove 1 Song  ";
		} else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)selectedRowsCount];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1 || self.segmentedControl.selectedSegmentIndex == 2) {
		if (selectedRowsCount == 0) {
			self.deleteSongsLabel.text = @"Select All";
		} else if (selectedRowsCount == 1) {
			self.deleteSongsLabel.text = @"Remove 1 Playlist";
		} else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)selectedRowsCount];
		}
	}
	
	self.savePlaylistLabel.hidden = YES;
	self.playlistCountLabel.hidden = YES;
	self.deleteSongsLabel.hidden = NO;
}
		
- (void)hideDeleteButton {
    NSUInteger selectedRowsCount = self.tableView.indexPathsForSelectedRows.count;
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (selectedRowsCount == 0) {
            if (self.isEditing) {
                self.deleteSongsLabel.text = @"Clear Playlist";
            } else {
                self.savePlaylistLabel.hidden = NO;
                self.playlistCountLabel.hidden = NO;
                self.deleteSongsLabel.hidden = YES;
            }
		} else if (selectedRowsCount == 1) {
			self.deleteSongsLabel.text = @"Remove 1 Song  ";
		} else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Songs", (unsigned long)selectedRowsCount];
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1 || self.segmentedControl.selectedSegmentIndex == 2) {
		if (selectedRowsCount == 0) {
            if (self.isEditing) {
                self.deleteSongsLabel.text = @"Clear Playlists";
            } else {
                self.savePlaylistLabel.hidden = NO;
                self.playlistCountLabel.hidden = NO;
                self.deleteSongsLabel.hidden = YES;
            }
		} else if (selectedRowsCount == 1) {
			self.deleteSongsLabel.text = @"Remove 1 Playlist";
		} else {
			self.deleteSongsLabel.text = [NSString stringWithFormat:@"Remove %lu Playlists", (unsigned long)selectedRowsCount];
		}
	}
}

- (void)uploadPlaylist:(NSString*)name {
//	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
//
//	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
//	NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//	NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
//	NSString *table = playlistS.isShuffle ? shufTable : currTable;
//
//	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
//		 for (int i = 0; i < self.currentPlaylistCount; i++) {
//			 @autoreleasepool {
//				 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
//				 [songIds addObject:n2N(aSong.songId)];
//			 }
//		 }
//	 }];
//	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
//	NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
//    NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
//        }];
//    }];
//    [dataTask resume];
//
//    self.tableView.scrollEnabled = NO;
//    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}

- (void)deleteCurrentPlaylistSongsAtRowIndexes:(NSArray<NSNumber*> *)rowIndexes {
    
    [playlistS deleteSongs:rowIndexes];
    [self updateCurrentPlaylistCount];
    
//        [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationRight];
    [self.tableView reloadData];
    
    [self editPlaylistAction:nil];
    [self segmentAction:nil];
}

- (void)deleteLocalPlaylistsAtRowIndexes:(NSArray<NSNumber*> *)rowIndexes {
    // Sort the row indexes to make sure they're accending
    NSArray<NSNumber*> *sortedRowIndexes = [rowIndexes sortedArrayUsingSelector:@selector(compare:)];
    
    [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"DROP TABLE localPlaylistsTemp"];
        [db executeUpdate:@"CREATE TABLE localPlaylistsTemp(playlist TEXT, md5 TEXT)"];
        for (NSNumber *index in [sortedRowIndexes reverseObjectEnumerator]) {
            @autoreleasepool {
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
    
    [self editPlaylistAction:nil];
    [self segmentAction:nil];
}

- (void)deleteServerPlaylistsAtRowIndexes:(NSArray<NSNumber*> *)rowIndexes {
    self.tableView.scrollEnabled = NO;
    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    
    for (NSNumber *index in rowIndexes) {
        NSString *playlistId = [[self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:[index intValue]] playlistId];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"deletePlaylist" parameters:@{@"id": n2N(playlistId)}];
        NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                // TODO: Handle error
            }
            [EX2Dispatch runInMainThreadAsync:^{
                [viewObjectsS hideLoadingScreen];
                [self segmentAction:nil];
            }];
        }];
        [dataTask resume];
    }
}

- (void)deleteAction {
	[self unregisterForNotifications];
	
    NSMutableArray *selectedRowIndexes = [self selectedRowIndexes];
	if (self.segmentedControl.selectedSegmentIndex == 0) {
        [self deleteCurrentPlaylistSongsAtRowIndexes:selectedRowIndexes];
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
        [self deleteLocalPlaylistsAtRowIndexes:selectedRowIndexes];
	}
	
	[viewObjectsS hideLoadingScreen];
	
	[self registerForNotifications];	
}

- (void)savePlaylistAction:(id)sender {
    NSMutableArray *selectedRowIndexes = [self selectedRowIndexes];
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (self.deleteSongsLabel.hidden == YES) {
			if (!self.isEditing) {
				if (settingsS.isOfflineMode) {
					[self showSavePlaylistAlert];
				} else {
//					self.savePlaylistLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
//					self.playlistCountLabel.backgroundColor = [UIColor colorWithRed:0.008 green:.46 blue:.933 alpha:1];
					
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
			if (selectedRowIndexes.count == 0) {
				// Select all the rows
				for (int i = 0; i < self.currentPlaylistCount; i++) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
				}
				[self showDeleteButton];
			} else {
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(deleteAction) withObject:nil afterDelay:0.05];
			}
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
		if (self.deleteSongsLabel.hidden == NO) {
			if (selectedRowIndexes.count == 0) {
				// Select all the rows
				NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
				for (int i = 0; i < count; i++) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
				}
				[self showDeleteButton];
			} else {
				// Delete action
				[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
				[self performSelector:@selector(deleteAction) withObject:nil afterDelay:0.05];
			}
		}
	} else if (self.segmentedControl.selectedSegmentIndex == 2) {
		if (self.deleteSongsLabel.hidden == NO) {
			if (selectedRowIndexes.count == 0) {
				// Select all the rows
				NSUInteger count = [self.serverPlaylistsDataModel.serverPlaylists count];
				for (int i = 0; i < count; i++) {
                    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
				}
				[self showDeleteButton];
			} else {
                [self deleteServerPlaylistsAtRowIndexes:selectedRowIndexes];
			}
		}
	}
}

- (void)connectionQueueDidFinish:(id)connectionQueue {
	[viewObjectsS hideLoadingScreen];
	self.tableView.scrollEnabled = YES;
	[self editPlaylistAction:nil];
	[self segmentAction:nil];
}

- (void)cancelLoad {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
        [self recreateSharedSession];
	} else {
        [self recreateSharedSession];
        [self.serverPlaylistsDataModel cancelLoad];
        [viewObjectsS hideLoadingScreen];
	}
}

- (void)showSavePlaylistAlert {
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Playlist" message:nil preferredStyle:UIAlertControllerStyleAlert];
//    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
//        textField.placeholder = @"Playlist name";
//    }];
//    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//        NSString *name = [[[alert textFields] firstObject] text];
//        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
//            // Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
//            NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", name.md5];
//            if (test) {
//                // If it exists, ask to overwrite
//                [self showOverwritePlaylistAlert:name];
//            } else {
//                NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
//                NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//                NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
//                NSString *table = playlistS.isShuffle ? shufTable : currTable;
//                
//                [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
//                    [db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", name, name.md5];
//                    [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
//                    
//                    [db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
//                    if (db.hadError) { DDLogError(@"[PlaylistsViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
//                    [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
//                    [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
//                }];
//            }
//        } else {
//            NSString *tableName = [NSString stringWithFormat:@"splaylist%@", name.md5];
//            if ([databaseS.localPlaylistsDbQueue tableExists:tableName]) {
//                // If it exists, ask to overwrite
//                [self showOverwritePlaylistAlert:name];
//            } else {
//                [self uploadPlaylist:name];
//            }
//        }
//    }]];
//    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
//    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showOverwritePlaylistAlert:(NSString *)name {
//    NSString *message = [NSString stringWithFormat:@"A playlist named \"%@\" already exists. Would you like to overwrite it?", name];
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Overwrite?" message:message preferredStyle:UIAlertControllerStyleAlert];
//    [alert addAction:[UIAlertAction actionWithTitle:@"Overwrite" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
//        // If yes, overwrite the playlist
//        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
//            NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", settingsS.urlString.md5];
//            NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//            NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
//            NSString *table = playlistS.isShuffle ? shufTable : currTable;
//            
//            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
//                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", name.md5]];
//                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
//                
//                [db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
//                if (db.hadError) { DDLogError(@"[PlaylistsViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
//                [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
//                [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
//            }];
//        } else {
//            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
//                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", name.md5]];
//            }];
//            
//            [self uploadPlaylist:name];
//        }
//    }]];
//    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
//    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectRow {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		[self.tableView reloadData];
		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
		}
	}
}

#pragma mark - ISMSLoader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    [self.tableView reloadData];
    
    // If the list is empty, display the no playlists overlay screen
    if ([self.serverPlaylistsDataModel.serverPlaylists count] == 0 && self.isNoPlaylistsScreenShowing == NO) {
		[self addNoPlaylistsScreen];
    } else {
        // Modify the header view to include the save and edit buttons
        [self addSaveEditButtons];
    }
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    DDLogError(@"[PlaylistsViewController] subsonic error %@: %@", errorCode, message);
    if (settingsS.isPopupsEnabled) {
        [EX2Dispatch runInMainThreadAsync:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
}

#pragma mark Table view methods

- (ISMSLocalPlaylist *)localPlaylistForIndex:(NSUInteger)index {
    if (self.segmentedControl.selectedSegmentIndex == 1) {
        NSString *name = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE ROWID = ?", @(index + 1)];
        NSString *md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(index + 1)];
        NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", md5]];
        return [[ISMSLocalPlaylist alloc] initWithName:name md5:md5 count:count];
    }
    return nil;
}

- (NSMutableArray<NSNumber*> *)selectedRowIndexes {
    NSMutableArray<NSNumber*> *selectedRowIndexes = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        [selectedRowIndexes addObject:@(indexPath.row)];
    }
    return selectedRowIndexes;
}

- (NSInteger)numberOfSectionIndexes {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        if (self.currentPlaylistCount > 200) {
            return 20;
        } else if (self.currentPlaylistCount > 20) {
            return self.currentPlaylistCount / 10;
        }
    }
    return 0;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (self.segmentedControl.selectedSegmentIndex == 0 && self.currentPlaylistCount >= 20) {
		if (!self.isEditing) {
			NSMutableArray *searchIndexes = [[NSMutableArray alloc] init];
			for (int x = 0; x < self.numberOfSectionIndexes; x++) {
				[searchIndexes addObject:@"●"];
			}
			return searchIndexes;
		}
	}
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		if (index == 0) {
			[tableView scrollRectToVisible:CGRectMake(0, 0, 320, 40) animated:NO];
		} else if (index == self.numberOfSectionIndexes - 1) {
			NSInteger row = self.currentPlaylistCount - 1;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		} else {
			NSInteger row = self.currentPlaylistCount / self.numberOfSectionIndexes * index;
			[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
			return -1;		
		}
	}
	
	return index - 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
		return self.currentPlaylistCount;
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
		return [databaseS.localPlaylistsDbQueue intForQuery:@"SELECT COUNT(*) FROM localPlaylists"];
    } else if (self.segmentedControl.selectedSegmentIndex == 2) {
		return self.serverPlaylistsDataModel.serverPlaylists.count;
    }
	
	return 0;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

// Set the editing style, set to none for no delete minus sign (overriding with own custom multi-delete boxes)
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
//	if (self.segmentedControl.selectedSegmentIndex == 0) {
//		NSInteger fromRow = fromIndexPath.row + 1;
//		NSInteger toRow = toIndexPath.row + 1;
//		
//		[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
//			NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
//			NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
//			NSString *table = playlistS.isShuffle ? shufTable : currTable;
//						
//			[db executeUpdate:@"DROP TABLE moveTemp"];
//			NSString *query = [NSString stringWithFormat:@"CREATE TABLE moveTemp (%@)", ISMSSong.standardSongColumnSchema];
//			[db executeUpdate:query];
//			
//			if (fromRow < toRow) {
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(fromRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ? AND ROWID <= ?", table], @(fromRow), @(toRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(toRow)];
//				
//				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
//				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
//			} else {
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID < ?", table], @(toRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID = ?", table], @(fromRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID >= ? AND ROWID < ?", table], @(toRow), @(fromRow)];
//				[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO moveTemp SELECT * FROM %@ WHERE ROWID > ?", table], @(fromRow)];
//				
//				[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", table]];
//				[db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE moveTemp RENAME TO %@", table]];
//			}
//		}];
//		
//		if (settingsS.isJukeboxEnabled) {
//			[jukeboxS replacePlaylistWithLocal];
//		}
//		
//		// Correct the value of currentPlaylistPosition
//		if (fromIndexPath.row == playlistS.currentIndex) {
//			playlistS.currentIndex = toIndexPath.row;
//		} else  {
//			if (fromIndexPath.row < playlistS.currentIndex && toIndexPath.row >= playlistS.currentIndex) {
//				playlistS.currentIndex = playlistS.currentIndex - 1;
//			} else if (fromIndexPath.row > playlistS.currentIndex && toIndexPath.row <= playlistS.currentIndex) {
//				playlistS.currentIndex = playlistS.currentIndex + 1;
//			}
//		}
//		
//		// Highlight the current playing song
//		if (playlistS.currentIndex >= 0 && playlistS.currentIndex < self.currentPlaylistCount) {
//			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:playlistS.currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
//		}
//		
//        if (!settingsS.isJukeboxEnabled) {
//			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
//        }
//	}
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
		return YES;
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
		return NO; //this will be changed to YES and will be fully editable
    } else if (self.segmentedControl.selectedSegmentIndex == 2) {
		return NO;
    }
	
	return NO;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    
	if (self.segmentedControl.selectedSegmentIndex == 0) {
        // Song
        cell.hideNumberLabel = NO;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = NO;
        cell.hideSecondaryLabel = NO;
        cell.number = indexPath.row + 1;
        [cell updateWithModel:[playlistS songForIndex:indexPath.row]];
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
        // Local playlist
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = YES;
        cell.hideDurationLabel = YES;
        cell.hideSecondaryLabel = NO;
        [cell updateWithModel:[self localPlaylistForIndex:indexPath.row]];
	} else if (self.segmentedControl.selectedSegmentIndex == 2) {
        // Server playlist
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = YES;
        cell.hideDurationLabel = YES;
        cell.hideSecondaryLabel = YES;
        [cell updateWithModel:[self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row]];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath) return;
    
    if (self.isEditing) {
        [self showDeleteButton];
        return;
    }
	
    if (self.segmentedControl.selectedSegmentIndex == 0)
    {
        ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
        if (!playedSong.isVideo) {
            [self showPlayer];
        }
    }
    else if (self.segmentedControl.selectedSegmentIndex == 1)
    {
        PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] init];
        playlistSongsViewController.md5 = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE ROWID = ?", @(indexPath.row + 1)];
        [self pushViewControllerCustom:playlistSongsViewController];
    }
    else if (self.segmentedControl.selectedSegmentIndex == 2)
    {
        PlaylistSongsViewController *playlistSongsViewController = [[PlaylistSongsViewController alloc] init];
        SUSServerPlaylist *playlist = [self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row];
        playlistSongsViewController.md5 = [playlist.playlistName md5];
        playlistSongsViewController.serverPlaylist = playlist;
        [self pushViewControllerCustom:playlistSongsViewController];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    
    if (self.isEditing) {
        [self hideDeleteButton];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        // Current Playlist
        ISMSSong *song = [playlistS songForIndex:indexPath.row];
        if (!song.isVideo) {
            return [SwipeAction downloadQueueAndDeleteConfigWithModel:song deleteHandler:^{
                [self deleteCurrentPlaylistSongsAtRowIndexes:@[@(indexPath.row)]];
            }];
        }
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        // Local Playlists
        return [SwipeAction downloadQueueAndDeleteConfigWithModel:[self localPlaylistForIndex:indexPath.row] deleteHandler:^{
            [self deleteLocalPlaylistsAtRowIndexes:@[@(indexPath.row)]];
        }];
    } else if (self.segmentedControl.selectedSegmentIndex == 2) {
        // Server Playlists
        return [SwipeAction downloadQueueAndDeleteConfigWithModel:[self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:indexPath.row] deleteHandler:^{
            [self deleteServerPlaylistsAtRowIndexes:@[@(indexPath.row)]];
        }];
        return nil;
    }
    return nil;
}

- (void)dealloc 
{
	[NSNotificationCenter removeObserverOnMainThread:self];
	self.serverPlaylistsDataModel.delegate = nil;
}

@end

