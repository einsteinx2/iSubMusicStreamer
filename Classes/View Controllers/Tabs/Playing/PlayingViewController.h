//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class SUSNowPlayingDAO;

@interface PlayingViewController : UITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isNothingPlayingScreenShowing;
@property (nonatomic, strong) UIImageView *nothingPlayingScreen;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) SUSNowPlayingDAO *dataModel;

- (void)cancelLoad;

@end
