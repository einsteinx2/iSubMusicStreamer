//
//  CurrentPlaylistViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CurrentPlaylistViewController : CustomUITableViewController 

@property (strong) UIView *headerView;
@property (strong) UILabel *savePlaylistLabel;
@property (strong) UILabel *deleteSongsLabel;
@property (strong) UILabel *playlistCountLabel;
@property (strong) UIButton *savePlaylistButton;
@property (strong) UILabel *editPlaylistLabel;

//NSTimer *songHighlightTimer;

@property BOOL savePlaylistLocal;

@property (strong) NSMutableData *receivedData;
@property (strong) NSURLConnection *connection;
@property (strong) NSMutableURLRequest *request;

@property NSUInteger currentPlaylistCount;

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
