//
//  CurrentPlaylistViewController.h
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CurrentPlaylistViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *saveEditContainer;
@property (nonatomic, strong) UILabel *savePlaylistLabel;
@property (nonatomic, strong) UILabel *deleteSongsLabel;
@property (nonatomic, strong) UILabel *playlistCountLabel;
@property (nonatomic, strong) UIButton *savePlaylistButton;
@property (nonatomic, strong) UILabel *editPlaylistLabel;
@property (nonatomic, strong) UIButton *editPlaylistButton;

//NSTimer *songHighlightTimer;

@property BOOL savePlaylistLocal;

@property NSUInteger currentPlaylistCount;

- (void) selectRow;

- (void) showDeleteButton;
- (void) hideDeleteButton;

@end
