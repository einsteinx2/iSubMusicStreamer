//
//  BookmarksViewController.h
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface BookmarksViewController : CustomUITableViewController

@property (nonatomic) BOOL isNoBookmarksScreenShowing;
@property (nonatomic, strong) UIImageView *noBookmarksScreen;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *bookmarkCountLabel;
@property (nonatomic, strong) UIButton *deleteBookmarksButton;
@property (nonatomic, strong) UILabel *deleteBookmarksLabel;
@property (nonatomic, strong) UILabel *editBookmarksLabel;
@property (nonatomic, strong) UIButton *editBookmarksButton;
@property (nonatomic, strong) NSArray *bookmarkIds;

@end
