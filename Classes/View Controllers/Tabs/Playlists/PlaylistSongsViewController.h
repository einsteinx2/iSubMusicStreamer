//
//  PlaylistSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LocalPlaylist, ServerPlaylist, ServerPlaylistLoader;

@interface PlaylistSongsViewController : UITableViewController

@property (nonatomic, strong) LocalPlaylist *localPlaylist;
@property (nonatomic, strong) ServerPlaylist *serverPlaylist;

@property (nonatomic, strong) ServerPlaylistLoader *serverPlaylistLoader;

@end
