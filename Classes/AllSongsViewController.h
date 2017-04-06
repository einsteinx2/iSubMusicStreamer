//
//  AllSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//


@class ISMSSong, ISMSAlbum, SUSAllSongsDAO, LoadingScreen, EGORefreshTableHeaderView;

@interface AllSongsViewController : CustomUITableViewController <UISearchBarDelegate, ISMSLoaderDelegate> 

@property (strong) UIButton *reloadButton;
@property (strong) UILabel *reloadLabel;
@property (strong) UIImageView *reloadImage;
@property (strong) UILabel *countLabel;
@property (strong) UILabel *reloadTimeLabel;
@property (strong) IBOutlet UISearchBar *searchBar;
@property BOOL letUserSelectRow;
@property (strong) NSURL *url;
@property NSInteger numberOfRows;
@property BOOL isSearching;
@property BOOL isProcessingArtists;
@property (strong) EGORefreshTableHeaderView *refreshHeaderView;
@property BOOL isReloading;
@property (strong) UIView *searchOverlay;
@property (strong) UIButton *dismissButton;
@property (strong) SUSAllSongsDAO *dataModel;
@property (strong) UIView *headerView;
@property (strong) NSArray *sectionInfo;
@property (strong) LoadingScreen *loadingScreen;

- (void)addCount;
- (void)doneSearching_Clicked:(id)sender;
- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(ISMSLoader*)theLoader;
- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end