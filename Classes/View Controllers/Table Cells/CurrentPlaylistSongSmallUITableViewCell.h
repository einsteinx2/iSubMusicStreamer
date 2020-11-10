//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface CurrentPlaylistSongSmallUITableViewCell : CustomUITableViewCell 

@property (strong) UILabel *numberLabel;
@property (strong) UILabel *songNameLabel;
@property (strong) UILabel *artistNameLabel;
@property (strong) UILabel *durationLabel;
@property (strong) UIImageView *nowPlayingImageView;

@end
