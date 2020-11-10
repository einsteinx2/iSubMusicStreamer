//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "SUSLoaderDelegate.h"

@class SUSNowPlayingDAO, EGORefreshTableHeaderView;

@interface PlayingViewController : CustomUITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isNothingPlayingScreenShowing;
@property (nonatomic, strong) UIImageView *nothingPlayingScreen;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) SUSNowPlayingDAO *dataModel;
@property (nonatomic, strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic) BOOL reloading;

- (void)cancelLoad;

@end
