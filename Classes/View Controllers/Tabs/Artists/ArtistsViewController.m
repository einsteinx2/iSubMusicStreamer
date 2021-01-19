//
//  ArtistsViewController.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ArtistsViewController.h"
#import "ServerListViewController.h"
#import "FolderDropdownControl.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <QuartzCore/QuartzCore.h>

@interface ArtistsViewController() <UISearchBarDelegate, APILoaderDelegate, FolderDropdownDelegate>
@end

@implementation ArtistsViewController

#pragma mark - Lifecycle

- (void)createDataModel {
    NSInteger mediaFolderId = settingsS.rootArtistsSelectedFolderId.integerValue;
    self.dataModel = [[RootArtistsViewModel alloc] initWithMediaFolderId:mediaFolderId delegate:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    [self createDataModel];
    
    self.title = @"Artists";
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    
    //Set defaults
    self.isSearching = NO;
    self.isCountShowing = NO;
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed];
        
    // Add the pull to refresh view
    __weak ArtistsViewController *weakSelf = self;
    self.tableView.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [weakSelf loadData:settingsS.rootArtistsSelectedFolderId.integerValue];
    }];
    
    [self.tableView registerClass:BlurredSectionHeader.class forHeaderFooterViewReuseIdentifier:BlurredSectionHeader.reuseId];
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
    self.tableView.rowHeight = Defines.rowHeight;
    
    if (self.dataModel.isCached) {
        [self addCount];
        [self.tableView setContentOffset:CGPointMake(0, 0) animated:NO];
    }
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
    [self addShowPlayerButton];
    
    if (!viewObjectsS.isArtistsLoading) {
        if (!self.dataModel.isCached) {
            [self loadData:settingsS.rootArtistsSelectedFolderId.integerValue];
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
        self.countLabel.text = [NSString stringWithFormat:@"%lu Artist", (unsigned long)self.dataModel.count];
    } else {
        self.countLabel.text = [NSString stringWithFormat:@"%lu Artists", (unsigned long)self.dataModel.count];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    self.reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:self.dataModel.reloadDate]];
}

- (void)removeCount {
    self.tableView.tableHeaderView = nil;
    self.isCountShowing = NO;
}

- (void)addCount {
    self.isCountShowing = YES;
    
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 157)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = self.view.backgroundColor;
    
    self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 9, 320, 30)];
    self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.countLabel.textColor = UIColor.labelColor;
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.font = [UIFont boldSystemFontOfSize:32];
    [self.headerView addSubview:self.countLabel];
    
    self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 40, 320, 14)];
    self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.reloadTimeLabel.textColor = UIColor.secondaryLabelColor;
    self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.reloadTimeLabel.font = [UIFont systemFontOfSize:11];
    [self.headerView addSubview:self.reloadTimeLabel];
    
    self.dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 61, 220, 40)];
    self.dropdown.delegate = self;
    [self.dropdown selectFolderWithId:self.dataModel.mediaFolderId];
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
    [self.tableView.refreshControl endRefreshing];
}

- (void)loadData:(NSInteger)mediaFolderId  {
    [self.dropdown updateFolders];
    viewObjectsS.isArtistsLoading = YES;
    [viewObjectsS showAlbumLoadingScreenOnMainWindowWithSender:self];
    self.dataModel.mediaFolderId = mediaFolderId;
    [self.dataModel startLoad];
}

- (void)loadingFinished:(APILoader *)loader {
    if (self.isCountShowing) {
        [self updateCount];
    } else {
        [self addCount];
    }
    
    [self.tableView reloadData];
    
    viewObjectsS.isArtistsLoading = NO;
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
    
    [self.tableView.refreshControl endRefreshing];
}

- (void)loadingFailed:(APILoader *)loader error:(NSError *)error {
    viewObjectsS.isArtistsLoading = NO;
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
    
    [self.tableView.refreshControl endRefreshing];
    
    // Inform the user that the connection failed.
    // NOTE: Must call after a delay or the refresh control won't hide
    [EX2Dispatch runInMainThreadAfterDelay:0.3 block:^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

#pragma mark Folder Dropdown Delegate

- (void)folderDropdownMoveViewsY:(float)y {
    [self.tableView performBatchUpdates:^{
        self.tableView.tableHeaderView.height += y;
        self.searchBar.y += y;
        self.tableView.tableHeaderView = self.tableView.tableHeaderView;

        NSSet *visibleSections = [NSSet setWithArray:[[self.tableView indexPathsForVisibleRows] valueForKey:@"section"]];
        for (NSNumber *section in visibleSections) {
            UIView *sectionHeader = [self.tableView headerViewForSection:section.intValue];
            sectionHeader.y += y;
        }
    } completion:nil];
}

- (void)folderDropdownSelectFolder:(NSInteger)mediaFolderId {
    // Save the default
    settingsS.rootArtistsSelectedFolderId = @(mediaFolderId);
    
    // Reload the data
    self.dataModel.mediaFolderId = mediaFolderId;
    self.isSearching = NO;
    if (self.dataModel.isCached) {
        [self.tableView reloadData];
        [self updateCount];
    } else {
        [self loadData:mediaFolderId];
    }
}

- (void)serverSwitched {
    [self createDataModel];
    if (!self.dataModel.isCached) {
        [self.tableView reloadData];
        [self removeCount];
    }
    [self folderDropdownSelectFolder:-1];
}

- (void)updateFolders {
    [self.dropdown updateFolders];
}

#pragma mark Button handling methods

- (void)reloadAction:(id)sender {
    [self loadData:settingsS.rootArtistsSelectedFolderId.integerValue];
}

#pragma mark SearchBar

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    if (self.isSearching) return;
    
    self.isSearching = YES;
    [self.dataModel clearSearch];
    
    [self.dropdown closeDropdownFast];
    [self.tableView setContentOffset:CGPointMake(0, 104) animated:YES];
    
    if (theSearchBar.text.length == 0) {
        [self createSearchOverlay];
    }
    
    // Add the done button.
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(searchBarSearchButtonClicked:)];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
    [self.dataModel clearSearch];
    if (searchText.length > 0)  {
        [self hideSearchOverlay];
        [self.dataModel searchWithName:self.searchBar.text];
    } else {
        [self createSearchOverlay];
        [self.tableView setContentOffset:CGPointMake(0, 104) animated:NO];
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    [self updateCount];
    
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self hideSearchOverlay];
    self.isSearching = NO;
    
    self.navigationItem.leftBarButtonItem = nil;
    [self.dataModel clearSearch];
    [self.tableView reloadData];
    [self.tableView setContentOffset:CGPointMake(0, 104) animated:YES];
}

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
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.searchOverlay.alpha = 0;
        } completion:^(BOOL finished) {
            [self.searchOverlay removeFromSuperview];
            self.searchOverlay = nil;
        }];
    }
}

#pragma mark TableView

- (ISMSTagArtist *)tagArtistAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return [self.dataModel tagArtistInSearchWithIndexPath:indexPath];
    } else {
        return [self.dataModel tagArtistWithIndexPath:indexPath];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return 1;
    }
    return self.dataModel.tableSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) {
        return self.dataModel.searchCount;
    } else if (self.dataModel.tableSections.count > section) {
        return self.dataModel.tableSections[section].itemCount;        
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISMSTagArtist *tagArtist = [self tagArtistAtIndexPath:indexPath];
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    [cell showCached:NO number:NO art:YES secondary:tagArtist.secondaryLabelText.hasValue duration:NO];
    [cell updateWithModel:[self tagArtistAtIndexPath:indexPath]];
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
    if (section >= self.dataModel.tableSections.count) return nil;
    
    BlurredSectionHeader *sectionHeader = [tableView dequeueReusableHeaderFooterViewWithIdentifier:BlurredSectionHeader.reuseId];
    sectionHeader.text = self.dataModel.tableSections[section].name;
    return sectionHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return 0;
    if (section >= self.dataModel.tableSections.count) return 0;
    
    return Defines.rowHeight - 5;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView  {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return nil;
    
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
    [titles addObject:@"{search}"];
    for (TableSection *section in self.dataModel.tableSections) {
        [titles addObject:section.name];
    }
    return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index  {
    if (self.isSearching && (self.dataModel.searchCount > 0 || self.searchBar.text.length > 0)) return -1;
    
    if (index == 0) {
        CGFloat yOffset = self.dropdown.hasMultipleMediaFolders ? 54 : 104;
        [self.tableView setContentOffset:CGPointMake(0, yOffset) animated:NO];
        return -1;
    }
    return index - 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
    if (!indexPath) return;
    [self pushViewControllerCustom:[[TagArtistViewController alloc] initWithTagArtist:[self tagArtistAtIndexPath:indexPath]]];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.isSearching || !self.dataModel.shouldContinueSearch || self.dataModel.searchCount == 0 || self.searchBar.text.length == 0) return;
    
    // If we're searching and we've reached the last cell, continue the search
    if (indexPath.row == self.dataModel.searchCount - 1) {
        [EX2Dispatch runInBackgroundAsync:^{
            [self.dataModel continueSearch];
            [EX2Dispatch runInMainThreadAsync:^{
                [tableView reloadData];
            }];
        }];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject<TableCellModel> *model = [self tagArtistAtIndexPath:indexPath];
    return [SwipeAction downloadAndQueueConfigWithModel:model];
}

@end

