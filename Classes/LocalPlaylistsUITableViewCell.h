//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface LocalPlaylistsUITableViewCell : CustomUITableViewCell 

@property (copy) NSString *md5;

@property NSUInteger playlistCount;

@property (strong) UILabel *playlistCountLabel;
@property (strong) UIScrollView *playlistNameScrollView;
@property (strong) UILabel *playlistNameLabel;

@end
