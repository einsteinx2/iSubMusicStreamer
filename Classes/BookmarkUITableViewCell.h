//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface BookmarkUITableViewCell : CustomUITableViewCell 

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UILabel *bookmarkNameLabel;
@property (strong) UIScrollView *nameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
