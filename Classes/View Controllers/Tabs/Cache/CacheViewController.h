//
//  CacheViewController.h
//  iSub
//
//  Created by Ben Baron on 6/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DownloadedFolderArtist;
@interface CacheViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>

@property (strong) NSLayoutConstraint *tableViewTopConstraint;
@property (strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UIView *segmentControlContainer;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIView *saveEditContainer;
@property (nonatomic, strong) UILabel *songsCountLabel;
@property (nonatomic, strong) UIButton *deleteSongsButton;
@property (nonatomic, strong) UILabel *deleteSongsLabel;
@property (nonatomic, strong) UILabel *editSongsLabel;
@property (nonatomic, strong) UIButton *editSongsButton;
@property (nonatomic) BOOL isSaveEditShowing;
@property (nonatomic, strong) UIImageView *playAllImage;
@property (nonatomic, strong) UILabel *playAllLabel;
@property (nonatomic, strong) UIButton *playAllButton;
@property (nonatomic, strong) UIImageView *shuffleImage;
@property (nonatomic, strong) UILabel *shuffleLabel;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic) BOOL isNoSongsScreenShowing;
@property (nonatomic, strong) UIImageView *noSongsScreen;
@property (nonatomic, strong) UIButton *jukeboxInputBlocker;
@property (nonatomic) BOOL showIndex;
//@property (nonatomic, strong) NSMutableArray *listOfArtists;
@property (nonatomic, strong) NSArray<DownloadedFolderArtist*> *downloadedFolderArtists;
@property (nonatomic, strong) NSMutableArray *listOfArtistsSections;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) UILabel *cacheSizeLabel;

- (void)updateCacheSizeLabel;
- (void)editSongsAction:(id)sender;

- (void)playAllPlaySong;
- (void)reloadTable;
- (void)updateQueueDownloadProgress;

@end
