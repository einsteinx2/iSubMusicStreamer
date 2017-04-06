//
//  SongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class Song;

@interface SongUITableViewCell : CustomUITableViewCell 

@property (copy) ISMSSong *mySong;

@property (strong) UILabel *trackNumberLabel;
@property (strong) UIScrollView *songNameScrollView;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;
@property (strong) UILabel *songDurationLabel;
@property (strong) UIImageView *nowPlayingImageView;

@end
