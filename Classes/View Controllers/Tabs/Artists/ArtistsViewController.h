//
//  ArtistsViewController.h
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FolderDropdownDelegate.h"
#import "SUSLoader.h"

@class SUSRootArtistsDAO, FolderDropdownControl;

@interface ArtistsViewController : UIViewController <UISearchBarDelegate, SUSLoaderDelegate, FolderDropdownDelegate>

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic) BOOL isSearching;
@property (nonatomic) BOOL isCountShowing;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIVisualEffectView *searchOverlay;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *reloadTimeLabel;
@property (nonatomic, strong) FolderDropdownControl *dropdown;
@property (nonatomic, strong) SUSRootArtistsDAO *dataModel;

// Loader Delegate Methods
- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader *)theLoader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
