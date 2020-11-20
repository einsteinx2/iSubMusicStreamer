//
//  AllAlbumsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AllAlbumsViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
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
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "SUSAllAlbumsDAO.h"
#import "SUSAllSongsDAO.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSIndex.h"
#import "ISMSIndex.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation AllAlbumsViewController

- (void)createDataModel {
	self.dataModel = [[SUSAllAlbumsDAO alloc] init];
	self.allSongsDataModel.delegate = nil;
	self.allSongsDataModel = [[SUSAllSongsDAO alloc] initWithDelegate:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
	
	self.title = @"Albums";
	
	//Set defaults
	self.letUserSelectRow = YES;	
	self.isSearching = NO;
	
	[self createDataModel];
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(createDataModel) name:ISMSNotification_ServerSwitched];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(loadingFinishedNotification) name:ISMSNotification_AllSongsLoadingFinished];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
	
    // Add the pull to refresh view
    __weak AllAlbumsViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [weakSelf reloadAction:nil];
    }];
    
    self.tableView.rowHeight = 65.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}


- (void)addCount {
	//Build the search and reload view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
	self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.countLabel.textColor = UIColor.labelColor;
	self.countLabel.textAlignment = NSTextAlignmentCenter;
	self.countLabel.font = [UIFont boldSystemFontOfSize:30];
	[self.headerView addSubview:self.countLabel];
	
	self.searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 50, 320, 40)];
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.placeholder = @"Album name";
	[self.headerView addSubview:self.searchBar];
	
	self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.reloadTimeLabel.textColor = UIColor.secondaryLabelColor;
	self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[self.headerView addSubview:self.reloadTimeLabel];
	
	self.countLabel.text = [NSString stringWithFormat:@"%lu Albums", (unsigned long)self.dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	self.reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settingsS.urlString]]]];
	
	self.tableView.tableHeaderView = self.headerView;
	
	[self.tableView reloadData];
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
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
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
                    
                    [self.allSongsDataModel restartLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Resume Load" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    [self showLoadingScreen];
                    
                    [self.allSongsDataModel startLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
			} else {
                NSString *message = @"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first.";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Load?"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    [self showLoadingScreen];
                    
                    [self.allSongsDataModel restartLoad];
                    self.tableView.tableHeaderView = nil;
                    [self.tableView reloadData];
                    
                    [self.refreshControl endRefreshing];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
			}
		}
	}
	
	[self.tableView reloadData];
	
	[Flurry logEvent:@"AllAlbumsTab"];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self hideLoadingScreen];
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

#pragma mark Button handling methods

- (void)reloadAction:(id)sender {
	if (![SUSAllSongsLoader isLoading]) {
        NSString *message = @"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reload?"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self showLoadingScreen];
            
            [self.allSongsDataModel restartLoad];
            self.tableView.tableHeaderView = nil;
            [self.tableView reloadData];
            
            [self.refreshControl endRefreshing];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        if (settingsS.isPopupsEnabled) {
            NSString *message = @"You cannot reload the Albums tab while the Folders or Songs tabs are loading";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Please Wait" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        [self.refreshControl endRefreshing];
    }
}

- (void) settingsAction:(id)sender {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark Search

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
	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	
	if ([theSearchBar.text length] == 0) {
		[self createSearchOverlay];
		
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	self.isSearching = YES;
	[self.tableView reloadData];
	
	// Add the done button.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
	if ([searchText length] > 0) {
		[self hideSearchOverlay];
		
		self.isSearching = YES;
		self.letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self.dataModel searchForAlbumName:searchText];
	} else {
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
		
		[self createSearchOverlay];
		
		self.isSearching = NO;
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE allAlbumsSearch"];
		}];
	}
	
	[self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar  {
	[self.searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar {
	[self hideSearchOverlay];
}

- (void)doneSearching_Clicked:(id)sender {
	self.tableView.tableHeaderView = nil;
	[self addCount];
	
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	
	self.isSearching = NO;
	self.letUserSelectRow = YES;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[self hideSearchOverlay];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 28) animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.isSearching) {
		return 1;
	} else {
		NSUInteger count = [self.dataModel.index count];
		return count;
	}
}

#pragma mark Tableview methods

- (ISMSAlbum *)albumAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching) {
        return [self.dataModel albumForPositionInSearch:(indexPath.row + 1)];
    } else {
        NSUInteger sectionStartIndex = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:indexPath.section] position];
        return [self.dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if(self.isSearching)
		return @"";
	
	if ([self.dataModel.index count] == 0)
		return @"";
	
	NSString *title = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] name];
	
	return title;
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (self.isSearching) {
		return nil;
	} else {
		NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
		[titles addObject:@"{search}"];
		for (ISMSIndex *item in self.dataModel.index) {
			[titles addObject:item.name];
		}
		return titles;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if(self.isSearching) return -1;
	
	if (index == 0) {
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
		return -1;
	}
	
	return index - 1;
}

- (NSIndexPath *)tableView:(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.letUserSelectRow ? indexPath : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.isSearching) {
		return self.dataModel.searchCount;
	} else {
		return [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] count];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = YES;
    cell.hideDurationLabel = YES;
    [cell updateWithModel:[self albumAtIndexPath:indexPath]];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
	
    [self pushViewControllerCustom:[[AlbumViewController alloc] initWithArtist:nil orAlbum:[self albumAtIndexPath:indexPath]]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<ISMSTableCellModel> *model = [self albumAtIndexPath:indexPath];
    return [SwipeAction downloadAndQueueConfigWithModel:model];
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
	} else if ([notification.name isEqualToString:ISMSNotification_AllSongsSorting]) {
		self.loadingScreen.loadingTitle1.text = @"Sorting";
		self.loadingScreen.loadingTitle2.text = @"";
		self.loadingScreen.loadingMessage1.text = name;
		self.loadingScreen.loadingMessage2.text = @"";
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

@end
