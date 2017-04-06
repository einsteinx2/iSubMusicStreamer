//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView;

@interface GenresAlbumUITableViewCell : CustomUITableViewCell 

@property NSInteger segment;
@property (copy) NSString *seg1;
@property (copy) NSString *genre;

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UIScrollView *albumNameScrollView;
@property (strong) UILabel *albumNameLabel;

@end
