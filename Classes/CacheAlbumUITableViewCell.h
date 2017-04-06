//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#include "CustomUITableViewCell.h"

@interface CacheAlbumUITableViewCell : CustomUITableViewCell 

@property (strong) NSArray *segments;

@property (strong) UIImageView *coverArtView;
@property (strong) UIScrollView *albumNameScrollView;
@property (strong) UILabel *albumNameLabel;

@end
