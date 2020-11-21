//
//  AllAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class ISMSAlbum, SUSAllAlbumsDAO, LoadingScreen, SUSAllSongsDAO;

@interface AllAlbumsViewController : UIViewController <UISearchBarDelegate, SUSLoaderDelegate>

@property (strong) IBOutlet UITableView *tableView;
@property (strong) UIButton *reloadButton;
@property (strong) UILabel *countLabel;
@property (strong) UILabel *reloadTimeLabel;
@property (strong) IBOutlet UISearchBar *searchBar;
@property (strong) NSURL *url;
@property BOOL isAllAlbumsLoading;
@property BOOL isProcessingArtists;
@property BOOL isSearching;
@property (strong) UIVisualEffectView *searchOverlay;
@property (strong) SUSAllAlbumsDAO *dataModel;
@property (strong) SUSAllSongsDAO *allSongsDataModel;
@property (strong) UIView *headerView;
@property (strong) NSArray *sectionInfo;
@property (strong) LoadingScreen *loadingScreen;

- (void)addCount;
- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end
