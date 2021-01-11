//
//  PlaylistsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class LocalPlaylist, ServerPlaylist, ServerPlaylistsLoader;

@interface PlaylistsViewController : UIViewController <SUSLoaderDelegate>

@property (strong) NSLayoutConstraint *tableViewTopConstraint;
@property (strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UIView *segmentControlContainer;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIImageView *noPlaylistsScreen;
@property (nonatomic) BOOL isNoPlaylistsScreenShowing;
@property (nonatomic, strong) UIView *saveEditContainer;
@property (nonatomic, strong) UILabel *savePlaylistLabel;
@property (nonatomic, strong) UILabel *playlistCountLabel;
@property (nonatomic, strong) UIButton *savePlaylistButton;
@property (nonatomic, strong) UILabel *deleteSongsLabel;
@property (nonatomic, strong) UILabel *editPlaylistLabel;
@property (nonatomic, strong) UIButton *editPlaylistButton;
@property (nonatomic) BOOL isPlaylistSaveEditShowing;
@property (nonatomic) BOOL savePlaylistLocal;
@property (nonatomic, strong) NSArray<LocalPlaylist*> *localPlaylists;
@property (nonatomic, strong) NSArray<ServerPlaylist*> *serverPlaylists;
@property (nonatomic, strong) ServerPlaylistsLoader *serverPlaylistsLoader;
@property (nonatomic) NSUInteger currentPlaylistCount;

- (void)showDeleteButton;
- (void)hideDeleteButton;

- (void)segmentAction:(id)sender;
- (void)updateCurrentPlaylistCount;

- (void)cancelLoad;

@end
