//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NowPlayingLoader;

@interface PlayingViewController: UITableViewController

@property (nonatomic) BOOL isNothingPlayingScreenShowing;
@property (nonatomic, strong) UIImageView *nothingPlayingScreen;
@property (nonatomic, strong) NowPlayingLoader *nowPlayingLoader;

- (void)cancelLoad;

@end
