//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LocalPlaylist, SUSServerPlaylist;

@interface PlaylistSongsViewController : UITableViewController

@property LocalPlaylist *localPlaylist;
@property (copy) SUSServerPlaylist *serverPlaylist;

@end
