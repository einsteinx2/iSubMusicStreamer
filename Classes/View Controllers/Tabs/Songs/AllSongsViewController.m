//
//  AllSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//


#import "AllSongsViewController.h"
#import "ServerListViewController.h"
#import "FoldersViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "LoadingScreen.h"
#import "SUSAllSongsLoader.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "SUSAllSongsDAO.h"
#import "ISMSSong+DAO.h"
#import "ISMSIndex.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation AllSongsViewController

#pragma mark - View Controller Lifecycle

- (void)createDataModel {
	self.dataModel.delegate = nil;
	self.dataModel = [[SUSAllSongsDAO alloc] init];
	self.dataModel.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = @"Songs";

	// Set defaults
	self.isProcessingArtists = YES;
	
	[self createDataModel];
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(createDataModel) name:ISMSNotification_ServerSwitched];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(loadingFinishedNotification) name:ISMSNotification_AllSongsLoadingFinished];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
	
    // Add the pull to refresh view
    __weak AllSongsViewController *weakSelf = self;
    self.tableView.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [weakSelf reloadAction:nil];
    }];
    
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:BlurredSectionHeader.class forHeaderFooterViewReuseIdentifier:BlurredSectionHeader.reuseId];
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated  {
	[super viewWillAppear:animated];
    	
	// Don't run this while the table is updating
	if ([SUSAllSongsLoader isLoading]) {
		[self showLoadingScreen];
	} else {
        [self addURLRefBackButton];

        self.navigationItem.rightBarButtonItem = nil;
		if (musicS.showPlayerIcon) {
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Defines.musicNoteImageSystemName] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
		}
		
		// Check if the data has been loaded
		if (self.dataModel.isDataLoaded) {
			[self addCount];
		} else {
			self.tableView.tableHeaderView = nil;
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]] isEqualToString:@"YES"]) {
                NSString *message = @"If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Resume Load?"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Restart Load" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    [self showLoadingScreen];
                    
                    [self.dataModel restartLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.tableView.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Resume Load" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self showLoadingScreen];
                    
                    [self.dataModel startLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.tableView.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
			} else {
                NSString *message = @"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first.";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Load?"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self showLoadingScreen];
                    
                    [self.dataModel restartLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.tableView.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
			}
		}
	}
	
	[self.tableView reloadData];
	
	[Flurry logEvent:@"AllSongsTab"];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[self hideLoadingScreen];
}

- (void)addCount {
	// Build the search and reload view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 110)];
	
	self.reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.reloadButton.frame = CGRectMake(0, 0, 320, 40);
	[self.headerView addSubview:self.reloadButton];
	
	self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 9, 320, 30)];
	self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.countLabel.textColor = UIColor.labelColor;
	self.countLabel.textAlignment = NSTextAlignmentCenter;
	self.countLabel.font = [UIFont boldSystemFontOfSize:30];
	[self.headerView addSubview:self.countLabel];
	
	self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, 320, 12)];
	self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.reloadTimeLabel.textColor = UIColor.secondaryLabelColor;
	self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[self.headerView addSubview:self.reloadTimeLabel];
	
    self.searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 61, 320, 40)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = @"Song name";
    [self.headerView addSubview:self.searchBar];
    
	self.countLabel.text = [NSString stringWithFormat:@"%lu Songs", (unsigned long)self.dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	self.reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settingsS.urlString]]]];
	
	self.tableView.tableHeaderView = self.headerView;
	[self.tableView reloadData];
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
	
    self.dataModel.delegate = nil;
}

#pragma mark LoaderDelegate methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	[self.tableView reloadData];
	[self createDataModel];
    [self hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
	// Don't do anything, handled by the notification
}

- (void)loadingFinishedNotification {
	[self.tableView reloadData];
	[self createDataModel];
	[self addCount];
    [self hideLoadingScreen];
}

#pragma mark Loading Display Handling

- (void)registerForLoadingNotifications {
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingArtists];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingAlbums];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsArtistName];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsAlbumName];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsSongName];
}

- (void)unregisterForLoadingNotifications {
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_AllSongsLoadingArtists];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_AllSongsLoadingAlbums];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_AllSongsArtistName];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_AllSongsAlbumName];
	[NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_AllSongsSongName];
}

- (void)updateLoadingScreen:(NSNotification *)notification {
	NSString *name = nil;
	if ([notification.object isKindOfClass:[NSString class]]) {
		name = [NSString stringWithString:(NSString *)notification.object];
	}

	if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingArtists]) {
		self.isProcessingArtists = YES;
		self.loadingScreen.loadingTitle1.text = @"Processing Artist:";
		self.loadingScreen.loadingTitle2.text = @"Processing Album:";
	} else if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingAlbums]) {
		self.isProcessingArtists = NO;
		self.loadingScreen.loadingTitle1.text = @"Processing Album:";
		self.loadingScreen.loadingTitle2.text = @"Processing Song:";
	} else if ([notification.name isEqualToString:ISMSNotification_AllSongsArtistName]) {
		self.isProcessingArtists = YES;
		self.loadingScreen.loadingTitle1.text = @"Processing Artist:";
		self.loadingScreen.loadingTitle2.text = @"Processing Album:";
		self.loadingScreen.loadingMessage1.text = name;
	} else if ([notification.name isEqualToString:ISMSNotification_AllSongsAlbumName]) {
        if (self.isProcessingArtists) {
			self.loadingScreen.loadingMessage2.text = name;
        } else {
			self.loadingScreen.loadingMessage1.text = name;
        }
	} else if ([notification.name isEqualToString:ISMSNotification_AllSongsSongName]) {
		self.isProcessingArtists = NO;
		self.loadingScreen.loadingTitle1.text = @"Processing Album:";
		self.loadingScreen.loadingTitle2.text = @"Processing Song:";
		self.loadingScreen.loadingMessage2.text = name;
	}
}

- (void)showLoadingScreen {
	self.loadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:@[@"Processing Artist:", @"", @"Processing Album:", @""] blockInput:YES mainWindow:NO];
	self.tableView.scrollEnabled = NO;
	self.tableView.allowsSelection = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.rightBarButtonItem = nil;
	
	[self registerForLoadingNotifications];
}

- (void)hideLoadingScreen {
	[self unregisterForLoadingNotifications];
	
	self.tableView.scrollEnabled = YES;
	self.tableView.allowsSelection = YES;
	
	// Hide the loading screen
	[self.loadingScreen hide];
	self.loadingScreen = nil;
}

#pragma mark - Button handling methods

- (void)reloadAction:(id)sender {
	if (!viewObjectsS.isArtistsLoading) {
        NSString *message = @"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists or albums, you should reload the Folders and Albums tabs first.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reload?" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self showLoadingScreen];
            [self.dataModel restartLoad];
            self.tableView.tableHeaderView = nil;
            [self.tableView reloadData];
            [self.tableView.refreshControl endRefreshing];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self.tableView.refreshControl endRefreshing];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
	} else {
        if (settingsS.isPopupsEnabled) {
            NSString *message = @"You cannot reload the Songs tab while the Folders or Albums tabs are loading";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Please Wait" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
		[self.tableView.refreshControl endRefreshing];
	}
}

- (void)settingsAction:(id)sender {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark UISearchBar delegate

- (void)createSearchOverlay {
    UIBlurEffectStyle effectStyle = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIBlurEffectStyleSystemUltraThinMaterialLight : UIBlurEffectStyleSystemUltraThinMaterialDark;
    self.searchOverlay = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:effectStyle]];
    self.searchOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [dismissButton addTarget:self action:@selector(searchBarSearchButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.searchOverlay.contentView addSubview:dismissButton];
    
    [self.view addSubview:self.searchOverlay];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.searchOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:50],
        [self.searchOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [dismissButton.leadingAnchor constraintEqualToAnchor:self.searchOverlay.leadingAnchor],
        [dismissButton.trailingAnchor constraintEqualToAnchor:self.searchOverlay.trailingAnchor],
        [dismissButton.topAnchor constraintEqualToAnchor:self.searchOverlay.topAnchor],
        [dismissButton.bottomAnchor constraintEqualToAnchor:self.searchOverlay.bottomAnchor]
    ]];
    
    // Animate the search overlay on screen
    self.searchOverlay.alpha = 0.0;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.searchOverlay.alpha = 1;
    } completion:nil];
}

- (void)hideSearchOverlay {
	if (self.searchOverlay) {
		// Animate the search overlay off screen
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.searchOverlay.alpha = 0;
        } completion:^(BOOL finished) {
            [self.searchOverlay removeFromSuperview];
            self.searchOverlay = nil;
        }];
	}
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar  {
	if (theSearchBar.text.length == 0) {
		[self createSearchOverlay];
	}
	
	self.isSearching = YES;
    [self.tableView setContentOffset:CGPointMake(0, 56) animated:YES];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(searchBarSearchButtonClicked:)];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
	if(searchText.length > 0) {
		[self hideSearchOverlay];
		[self.dataModel searchForSongName:searchText];
	} else {
		[self.tableView setContentOffset:CGPointMake(0, 56) animated:YES];
		[self createSearchOverlay];
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
			 [db executeUpdate:@"DROP TABLE allSongsSearch"];
		}];
	}
	
	[self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self hideSearchOverlay];
    self.isSearching = NO;
    
    self.navigationItem.leftBarButtonItem = nil;
    [self.tableView reloadData];
    [self.tableView setContentOffset:CGPointMake(0, 56) animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar {
    [theSearchBar resignFirstResponder];
}

#pragma mark UITableView delegate

- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return [self.dataModel songForPositionInSearch:(indexPath.row + 1)];
    } else {
        NSUInteger sectionStartIndex = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:indexPath.section] position];
        return [self.dataModel songForPosition:(sectionStartIndex + indexPath.row + 1)];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return 0;
    
    return Defines.rowHeight - 5;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
    
    BlurredSectionHeader *sectionHeader = [tableView dequeueReusableHeaderFooterViewWithIdentifier:BlurredSectionHeader.reuseId];
    sectionHeader.text = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] name];
    return sectionHeader;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
    
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
    [titles addObject:@"{search}"];
    for (ISMSIndex *item in self.dataModel.index) {
        [titles addObject:item.name];
    }
    return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return -1;
	
	if (index == 0) {
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
		return -1;
	}
	
	return index - 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return 1;
	
    return self.dataModel.index.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
		return self.dataModel.searchCount;
	} else if (self.dataModel.index.count > section) {
        return [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] count];
	}
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = YES;
    [cell updateWithModel:[self songAtIndexPath:indexPath]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
	
    // Clear the current playlist
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    
    // Add selected song to the playlist
    ISMSSong *aSong = [self songAtIndexPath:indexPath];
    [aSong addToCurrentPlaylistDbQueue];
    
    // If jukebox mode, send song id to server
    if (settingsS.isJukeboxEnabled) {
        [jukeboxS stop];
        [jukeboxS clearPlaylist];
        [jukeboxS addSong:aSong.songId];
    }
    
    // Set player defaults
    playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];

    // Start the song
    ISMSSong *playedSong = [musicS playSongAtPosition:0];
    if (!playedSong.isVideo) {
        [self showPlayer];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISMSSong *song = [self songAtIndexPath:indexPath];
    if (!song.isVideo) {
        return [SwipeAction downloadAndQueueConfigWithModel:song];
    }
    return nil;
}

@end

