//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class AsynchronousImageView, Song;

@interface PlaylistSongUITableViewCell : CustomUITableViewCell 

@property (strong) ISMSSong *mySong;

@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UILabel *numberLabel;
@property (strong) UIScrollView *nameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;

@end
