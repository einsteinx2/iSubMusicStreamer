//
//  RootViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FolderDropdownDelegate.h"

@class ISMSArtist, EGORefreshTableHeaderView, FolderDropdownControl, SUSRootFoldersDAO;

@interface FoldersViewController : CustomUITableViewController <UISearchBarDelegate, ISMSLoaderDelegate, FolderDropdownDelegate>

@property (nonatomic) BOOL letUserSelectRow;
@property (nonatomic) BOOL isSearching;
@property (nonatomic) BOOL isCountShowing;
@property (nonatomic, strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic) BOOL isReloading;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *reloadTimeLabel;
@property (nonatomic, strong) UIButton *blockerButton;
@property (nonatomic, strong) UIView *searchOverlay;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) FolderDropdownControl *dropdown;
@property (nonatomic, strong) SUSRootFoldersDAO *dataModel;

- (void)doneSearching_Clicked:(id)sender;

// Loader Delegate Methods
- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(ISMSLoader*)theLoader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
