//
//  FoldersViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootFoldersDAO, FolderDropdownControl;

@interface FoldersViewController : UIViewController

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic) BOOL isSearching;
@property (nonatomic) BOOL isCountShowing;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIVisualEffectView *searchOverlay;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *reloadTimeLabel;
@property (nonatomic, strong) FolderDropdownControl *dropdown;
@property (nonatomic, strong) RootFoldersDAO *dataModel;

@end
