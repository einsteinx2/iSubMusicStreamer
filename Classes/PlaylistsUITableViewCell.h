//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@class SUSServerPlaylist;

@interface PlaylistsUITableViewCell : CustomUITableViewCell 

@property (strong) UIScrollView *playlistNameScrollView;
@property (strong) UILabel *playlistNameLabel;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;

@property (copy) SUSServerPlaylist *serverPlaylist;

@property (nonatomic) BOOL isDownload;

- (void)cancelLoad;

@end
