//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FoldersViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "EGORefreshTableHeaderView.h"
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
	self.letUserSelectRow = YES;	
	self.isCountShowing = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed object:nil];
		
	// Add the pull to refresh view
	self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	[self.tableView addSubview:self.refreshHeaderView];
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	} else {
        if (self.dropdown.folders == nil || [self.dropdown.folders count] == 2) {
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
        } else {
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
        }
	}
	
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    self.tableView.rowHeight = 60;
	
	if ([self.dataModel isRootFolderIdCached])
		[self addCount];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.dataModel.delegate = nil;
	self.dropdown.delegate = nil;
}

#pragma mark - Loading

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
	
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 126)];
	self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.headerView.backgroundColor = ISMSHeaderColor;
	
    // This is a hack to prevent unwanted taps in the header, but it messes with voice over
	if (!UIAccessibilityIsVoiceOverRunning()) {
        self.blockerButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.blockerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.blockerButton.frame = self.headerView.frame;
        [self.headerView addSubview:self.blockerButton];
    }
	
	self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.countLabel.backgroundColor = [UIColor clearColor];
	self.countLabel.textColor = ISMSHeaderTextColor;
	self.countLabel.textAlignment = NSTextAlignmentCenter;
	self.countLabel.font = ISMSBoldFont(30);
	[self.headerView addSubview:self.countLabel];
	
	self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.reloadTimeLabel.backgroundColor = [UIColor clearColor];
	self.reloadTimeLabel.textColor = ISMSHeaderTextColor;
	self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
	self.reloadTimeLabel.font = ISMSRegularFont(11);
	[self.headerView addSubview:self.reloadTimeLabel];
	
	self.searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 86, 320, 40)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.placeholder = @"Folder name";
	[self.headerView addSubview:self.searchBar];
	
	self.dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 53, 220, 30)];
	self.dropdown.delegate = self;
	NSDictionary *dropdownFolders = [SUSRootFoldersDAO folderDropdownFolders];
	if (dropdownFolders != nil) {
		self.dropdown.folders = dropdownFolders;
	} else {
		self.dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:@-1];
	}
	[self.dropdown selectFolderWithId:self.dataModel.selectedFolderId];
	
	[self.headerView addSubview:self.dropdown];
	
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
	[self dataSourceDidFinishLoadingNewData];
}

-(void)loadData:(NSNumber *)folderId  {
	[self.dropdown updateFolders];
	
	viewObjectsS.isArtistsLoading = YES;
	
	//allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:@[@"Processing Folders", @"", @"", @""]  blockInput:YES mainWindow:NO];
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	self.dataModel.selectedFolderId = folderId;
	[self.dataModel startLoad];
}

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
	
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
	
	if (!UIDevice.isIPad)
		self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Folder Dropdown Delegate

- (void)folderDropdownMoveViewsY:(float)y {
	//[self.tableView beginUpdates];
	self.tableView.tableHeaderView.height += y;
	self.searchBar.y += y;
	self.blockerButton.frame = self.tableView.tableHeaderView.frame;
	
	/*for (UIView *subView in self.tableView.subviews)
	{
		if (subView != self.tableView.tableHeaderView && subView != refreshHeaderView)
			subView.y += y;
	}*/
	
	/*for (UITableViewCell *cell in self.tableView.visibleCells)
	{
		cell.y += y;
	}*/	
	//[self.tableView endUpdates];
	
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)folderDropdownViewsFinishedMoving {
	//self.tableView.tableHeaderView = self.tableView.tableHeaderView;
	/*[self.tableView setNeedsLayout];
	[self.tableView reloadData];*/
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

#pragma mark - Button handling methods

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
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}


#pragma mark -
#pragma mark SearchBar

- (void)createSearchOverlay {
	self.searchOverlay = [[UIView alloc] init];
	self.searchOverlay.frame = CGRectMake(0, 0, 480, 480);
	self.searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	self.searchOverlay.alpha = 0.0;
	self.tableView.tableFooterView = self.searchOverlay;
	
	self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.dismissButton addTarget:self action:@selector(doneSearching_Clicked:) forControlEvents:UIControlEventTouchUpInside];
	self.dismissButton.frame = self.view.bounds;
	self.dismissButton.enabled = NO;
	[self.searchOverlay addSubview:self.dismissButton];
	
	// Animate the search overlay on screen
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.searchOverlay.alpha = 1;
        self.dismissButton.enabled = YES;
    } completion:nil];
}

- (void)hideSearchOverlay {
	if (self.searchOverlay) {
		// Animate the search overlay off screen
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.searchOverlay.alpha = 0;
            self.dismissButton.enabled = NO;
        } completion:^(BOOL finished) {
            [self.searchOverlay removeFromSuperview];
            self.searchOverlay = nil;
        }];
	}
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
	if (self.isSearching) return;
	
	// Remove the index bar
	self.isSearching = YES;
	[self.dataModel clearSearchTable];
	[self.tableView reloadData];
	
	[self.dropdown closeDropdownFast];
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
	
	if ([theSearchBar.text length] == 0) {
		[self createSearchOverlay];
				
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
	if ([searchText length] > 0)  {
		[self hideSearchOverlay];
		
		self.letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		
		[self.dataModel searchForFolderName:self.searchBar.text];
		
		[self.tableView reloadData];
	} else {
		[self createSearchOverlay];
				
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		
		[self.dataModel clearSearchTable];
		
		[self.tableView reloadData];
		
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
	//[self searchTableView];
	[self.searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar {
	[self hideSearchOverlay];
}

- (void)doneSearching_Clicked:(id)sender {
	[self updateCount];
	
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	
	self.letUserSelectRow = YES;
	self.isSearching = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[self hideSearchOverlay];
	
	[self.dataModel clearSearchTable];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
}

#pragma mark TableView

- (ISMSArtist *)artistAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching) {
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
    return self.isSearching ? 1 : self.dataModel.indexNames.count;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.isSearching) {
        return self.dataModel.searchCount;
	} else if (self.dataModel.indexCounts.count > section) {
        return [[self.dataModel.indexCounts objectAtIndexSafe:section] intValue];
	}
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = YES;
    cell.hideCoverArt = YES;
    cell.hideSecondaryLabel = YES;
    cell.hideDurationLabel = YES;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    [cell updateWithModel:[self artistAtIndexPath:indexPath]];

	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section  {
	if (self.isSearching) return @"";
	if (self.dataModel.indexNames.count == 0) return @"";
    return [self.dataModel.indexNames objectAtIndexSafe:section];
}


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
	if (self.isSearching) return nil;
	
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
	[titles addObject:@"{search}"];
	[titles addObjectsFromArray:[self.dataModel indexNames]];
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
	if (self.isSearching) return -1;
	
    if (index == 0) {
        if (self.dropdown.folders == nil || [self.dropdown.folders count] == 2) {
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
        } else {
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
        }
		return -1;
    }
	return index - 1;
}


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
    return self.letUserSelectRow ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
	
	if (viewObjectsS.isCellEnabled) {
		[self pushViewControllerCustom:[[AlbumViewController alloc] initWithArtist:[self artistAtIndexPath:indexPath] orAlbum:nil]];
	} else {
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<ISMSTableCellModel> *model = [self artistAtIndexPath:indexPath];
    return [SwipeAction downloadAndQueueConfigWithModel:model];
}

#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView.isDragging) {
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.isReloading) {
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.isReloading) {
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (scrollView.contentOffset.y <= - 65.0f && !self.isReloading)  {
		self.isReloading = YES;
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
        [self.refreshHeaderView setState:EGOOPullRefreshLoading];
        
        [UIView animateWithDuration:0.2 animations:^{
            self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
        }];
	}
}

- (void)dataSourceDidFinishLoadingNewData {
	self.isReloading = NO;
	
    [UIView animateWithDuration:0.3 animations:^{
        [self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
    }];

	[self.refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

