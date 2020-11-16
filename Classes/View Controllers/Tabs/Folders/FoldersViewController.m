//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FoldersViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "FolderDropdownControl.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "SUSAllSongsLoader.h"
#import "CustomUIAlertView.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "SUSRootFoldersDAO.h"
#import "ISMSArtist.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <QuartzCore/QuartzCore.h>

@implementation FoldersViewController

#pragma mark - Lifecycle

- (void)createDataModel {
	self.dataModel = [[SUSRootFoldersDAO alloc] initWithDelegate:self];
	self.dataModel.selectedFolderId = [settingsS rootFoldersSelectedFolderId];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
	
	[self createDataModel];
	
	self.title = @"Folders";
		
	//Set defaults
	self.isSearching = NO;
	self.isCountShowing = NO;
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed];
		
	// Add the pull to refresh view
    __weak FoldersViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [weakSelf loadData:[settingsS rootFoldersSelectedFolderId]];
    }];
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	} else {
        if (self.dropdown.folders == nil || [self.dropdown.folders count] == 2) {
			[self.tableView setContentOffset:CGPointMake(0, 104) animated:NO];
        } else {
			[self.tableView setContentOffset:CGPointMake(0, 54) animated:NO];
        }
	}
    
    [self.tableView registerClass:BlurredSectionHeader.class forHeaderFooterViewReuseIdentifier:BlurredSectionHeader.reuseId];
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    self.tableView.rowHeight = 60;
	
	if ([self.dataModel isRootFolderIdCached])
		[self addCount];
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
	
	if (![SUSAllSongsLoader isLoading] && !viewObjectsS.isArtistsLoading) {
		if (![self.dataModel isRootFolderIdCached]) {
			[self loadData:[settingsS rootFoldersSelectedFolderId]];
		}
	}
	
	[Flurry logEvent:@"FoldersTab"];
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
	self.dataModel.delegate = nil;
    self.dropdown.delegate = nil;
}

#pragma mark Loading

- (void)updateCount {
    if (self.dataModel.count == 1) {
		self.countLabel.text = [NSString stringWithFormat:@"%lu Folder", (unsigned long)self.dataModel.count];
    } else {
		self.countLabel.text = [NSString stringWithFormat:@"%lu Folders", (unsigned long)self.dataModel.count];
    }
    
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	self.reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[settingsS rootFoldersReloadTime]]];
}

- (void)removeCount {
	self.tableView.tableHeaderView = nil;
	self.isCountShowing = NO;
}

- (void)addCount {
	self.isCountShowing = YES;
	
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 157)];
	self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = UIColor.systemBackgroundColor;//ISMSHeaderColor;
	
	self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 9, 320, 30)];
	self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.countLabel.backgroundColor = [UIColor clearColor];
    self.countLabel.textColor = UIColor.labelColor;//ISMSHeaderTextColor;
	self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.font = [UIFont boldSystemFontOfSize:32];//ISMSBoldFont(30);
	[self.headerView addSubview:self.countLabel];
	
	self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, 320, 14)];
	self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.reloadTimeLabel.backgroundColor = [UIColor clearColor];
    self.reloadTimeLabel.textColor = UIColor.labelColor;//ISMSHeaderTextColor;
	self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.reloadTimeLabel.font = [UIFont systemFontOfSize:11];//ISMSRegularFont(11);
	[self.headerView addSubview:self.reloadTimeLabel];
	
    self.dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 61, 220, 40)];
    self.dropdown.delegate = self;
    NSDictionary *dropdownFolders = [SUSRootFoldersDAO folderDropdownFolders];
    if (dropdownFolders != nil) {
        self.dropdown.folders = dropdownFolders;
    } else {
        self.dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:@-1];
    }
    [self.dropdown selectFolderWithId:self.dataModel.selectedFolderId];
    [self.headerView addSubview:self.dropdown];
    
	self.searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 111, 320, 40)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
	self.searchBar.delegate = self;
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.placeholder = @"Folder name";
	[self.headerView addSubview:self.searchBar];
	
	[self updateCount];
    
    // Special handling for voice over users
    if (UIAccessibilityIsVoiceOverRunning()) {
        // Add a refresh button
        UIButton *voiceOverRefresh = [UIButton buttonWithType:UIButtonTypeCustom];
        voiceOverRefresh.frame = CGRectMake(0, 0, 50, 50);
        [voiceOverRefresh addTarget:self action:@selector(reloadAction:) forControlEvents:UIControlEventTouchUpInside];
        voiceOverRefresh.accessibilityLabel = @"Reload Folders";
        [self.headerView addSubview:voiceOverRefresh];
        
        // Resize the two labels at the top so the refresh button can be pressed
        self.countLabel.frame = CGRectMake(50, 5, 220, 30);
        self.reloadTimeLabel.frame = CGRectMake(50, 36, 220, 12);
    }
	
	self.tableView.tableHeaderView = self.headerView;
}

- (void)cancelLoad {
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
    [self.refreshControl endRefreshing];
}

- (void)loadData:(NSNumber *)folderId  {
    [self.dropdown updateFolders];
	viewObjectsS.isArtistsLoading = YES;
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	self.dataModel.selectedFolderId = folderId;
	[self.dataModel startLoad];
}

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
    [self.refreshControl endRefreshing];
	
	// Inform the user that the connection failed.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error"
                                                                   message:error.localizedDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    //DLog(@"loadingFinished called");
    if (self.isCountShowing) {
		[self updateCount];
    } else {
		[self addCount];		
    }
    
	[self.tableView reloadData];
	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
    [self.refreshControl endRefreshing];
}

#pragma mark Folder Dropdown Delegate

- (void)folderDropdownMoveViewsY:(float)y {
    [self.tableView performBatchUpdates:^{
        self.tableView.tableHeaderView.height += y;
        self.searchBar.y += y;
        self.tableView.tableHeaderView = self.tableView.tableHeaderView;
//        for (int section = 0; section < self.dataModel.indexNames.count; section++) {
//            UIView *sectionHeader = [self.tableView headerViewForSection:section];
//            sectionHeader.y += y;
//        }
        NSSet *visibleSections = [NSSet setWithArray:[[self.tableView indexPathsForVisibleRows] valueForKey:@"section"]];
        for (NSNumber *section in visibleSections) {
            UIView *sectionHeader = [self.tableView headerViewForSection:section.intValue];
            sectionHeader.y += y;
        }
    } completion:nil];
}

- (void)folderDropdownSelectFolder:(NSNumber *)folderId {
	[self.dropdown selectFolderWithId:folderId];
	 
	// Save the default
	settingsS.rootFoldersSelectedFolderId = folderId;
	
	// Reload the data
	self.dataModel.selectedFolderId = folderId;
	self.isSearching = NO;
	if ([self.dataModel isRootFolderIdCached]) {
		[self.tableView reloadData];
		[self updateCount];
	} else {
		[self loadData:folderId];
	}
}

- (void)serverSwitched {
	[self createDataModel];
	if (![self.dataModel isRootFolderIdCached]) {
		[self.tableView reloadData];
		[self removeCount];
	}
	[self folderDropdownSelectFolder:@-1];
}

- (void)updateFolders {
	[self.dropdown updateFolders];
}

#pragma mark Button handling methods

- (void)reloadAction:(id)sender {
	if (![SUSAllSongsLoader isLoading]) {
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
	} else {
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Artists tab while the Albums or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
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

#pragma mark SearchBar

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    if (self.isSearching) return;
    
    // Remove the index bar
    self.isSearching = YES;
    [self.dataModel clearSearchTable];
    [self.tableView reloadData];
    
    [self.dropdown closeDropdownFast];
    [self.tableView setContentOffset:CGPointMake(0, 104) animated:YES];
    
    if ([theSearchBar.text length] == 0) {
        [self createSearchOverlay];
                
//        self.letUserSelectRow = NO;
        self.tableView.scrollEnabled = NO;
    }
    
    //Add the done button.
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(searchBarSearchButtonClicked:)];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
    if (searchText.length > 0)  {
        [self hideSearchOverlay];
        self.tableView.scrollEnabled = YES;
        [self.dataModel searchForFolderName:self.searchBar.text];
        [self.tableView reloadData];
    } else {
        [self createSearchOverlay];
        self.tableView.scrollEnabled = NO;
        [self.dataModel clearSearchTable];
        [self.tableView reloadData];
        [self.tableView setContentOffset:CGPointMake(0, 104) animated:NO];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    [self updateCount];
    
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self hideSearchOverlay];
    self.isSearching = NO;
    
    self.navigationItem.leftBarButtonItem = nil;
    [self.dataModel clearSearchTable];
    [self.tableView reloadData];
    [self.tableView setContentOffset:CGPointMake(0, 104) animated:YES];
    self.tableView.scrollEnabled = YES;
}

- (void)createSearchOverlay {
    self.searchOverlay = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];//[[UIView alloc] init];
    self.searchOverlay.frame = CGRectMake(0, 00, self.tableView.frame.size.width, self.tableView.frame.size.height);
    self.searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.searchOverlay.alpha = 0.0;
    self.tableView.tableFooterView = self.searchOverlay;
    
    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [dismissButton addTarget:self action:@selector(searchBarSearchButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    dismissButton.frame =  self.searchOverlay.bounds;
    [self.searchOverlay.contentView addSubview:dismissButton];
    
    // Animate the search overlay on screen
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.searchOverlay.alpha = 1;
    } completion:nil];
}

- (void)hideSearchOverlay {
    if (self.searchOverlay) {
        // Animate the search overlay off screen
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.searchOverlay.alpha = 0;
        } completion:^(BOOL finished) {
            self.tableView.tableFooterView = nil;
            self.searchOverlay = nil;
        }];
    }
}

#pragma mark TableView

- (ISMSArtist *)artistAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return [self.dataModel artistForPositionInSearch:(indexPath.row + 1)];
    } else {
        NSArray *indexPositions = self.dataModel.indexPositions;
        if (indexPositions.count > indexPath.section) {
            NSUInteger sectionStartIndex = [[indexPositions objectAtIndexSafe:indexPath.section] intValue];
            return [self.dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
        }
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
//    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
//        return 1;
//    }
    return self.isSearching ? 1 : self.dataModel.indexNames.count;
    return self.dataModel.indexNames.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isSearching) { //&& (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return self.dataModel.searchCount;
	} else if (self.dataModel.indexCounts.count > section) {
        return [[self.dataModel.indexCounts objectAtIndexSafe:section] intValue];
	}
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = YES;
    cell.hideCoverArt = YES;
    cell.hideSecondaryLabel = YES;
    cell.hideDurationLabel = YES;
    [cell updateWithModel:[self artistAtIndexPath:indexPath]];
	return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.isSearching) return nil; //&& (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
    if (self.dataModel.indexNames.count == 0) return nil;
    
    BlurredSectionHeader *sectionHeader = [tableView dequeueReusableHeaderFooterViewWithIdentifier:BlurredSectionHeader.reuseId];
    sectionHeader.text = [self.dataModel.indexNames objectAtIndexSafe:section];
    return sectionHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.isSearching) return 0; //&& (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return 0;
    if (self.dataModel.indexNames.count == 0) return 0;
    
    return 60;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
    if (self.isSearching) return nil;// && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
	
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
	[titles addObject:@"{search}"];
	[titles addObjectsFromArray:[self.dataModel indexNames]];
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
    if (self.isSearching) return -1;// && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return -1;
	
    if (index == 0) {
        if (self.dropdown.folders == nil || [self.dropdown.folders count] == 2) {
			[self.tableView setContentOffset:CGPointMake(0, 104) animated:NO];
        } else {
			[self.tableView setContentOffset:CGPointMake(0, 54) animated:NO];
        }
		return -1;
    }
	return index - 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
    [self pushViewControllerCustom:[[AlbumViewController alloc] initWithArtist:[self artistAtIndexPath:indexPath] orAlbum:nil]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<ISMSTableCellModel> *model = [self artistAtIndexPath:indexPath];
    return [SwipeAction downloadAndQueueConfigWithModel:model];
}

@end

