//
//  SearchSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView, Song;

@interface SearchSongUITableViewCell : CustomUITableViewCell 

@property (copy) ISMSSong *mySong;
@property NSUInteger row;

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UIScrollView *songNameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
