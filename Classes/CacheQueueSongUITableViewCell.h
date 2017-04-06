//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#include "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface CacheQueueSongUITableViewCell : CustomUITableViewCell 

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UILabel *cacheInfoLabel;
@property (strong) UIScrollView *nameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;
@property (copy) NSString *md5;

@end
