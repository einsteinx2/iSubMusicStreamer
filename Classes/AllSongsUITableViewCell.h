//
//  AllSongsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"
#import "CellCachedIndicatorView.h"

@class AsynchronousImageView;

@interface AllSongsUITableViewCell : CustomUITableViewCell 

@property (copy) NSString *md5;

@property (strong) CellCachedIndicatorView *cachedIndicatorView;
@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UIScrollView *songNameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
