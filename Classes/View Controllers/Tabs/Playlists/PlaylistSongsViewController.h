//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EGORefreshTableHeaderView, SUSServerPlaylist;

@interface PlaylistSongsViewController : UITableViewController

@property (strong) EGORefreshTableHeaderView *refreshHeaderView;
@property(nonatomic) BOOL reloading;
@property (copy) NSString *md5;
@property NSUInteger playlistCount;
@property (copy) SUSServerPlaylist *serverPlaylist;

@end
