//
//  AllSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoader.h"

@class ISMSSong, ISMSAlbum, SUSAllSongsDAO, LoadingScreen;

@interface AllSongsViewController : UIViewController <UISearchBarDelegate, SUSLoaderDelegate> 

@property (strong) IBOutlet UITableView *tableView;
@property (strong) UIButton *reloadButton;
@property (strong) UILabel *reloadLabel;
@property (strong) UIImageView *reloadImage;
@property (strong) UILabel *countLabel;
@property (strong) UILabel *reloadTimeLabel;
@property (strong) IBOutlet UISearchBar *searchBar;
@property (strong) NSURL *url;
@property NSInteger numberOfRows;
@property BOOL isSearching;
@property BOOL isProcessingArtists;
@property (strong) UIVisualEffectView *searchOverlay;
@property (strong) SUSAllSongsDAO *dataModel;
@property (strong) UIView *headerView;
@property (strong) NSArray *sectionInfo;
@property (strong) LoadingScreen *loadingScreen;

- (void)addCount;
- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader *)theLoader;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end
