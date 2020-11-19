//
//  MenuViewController.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h> 

@class PlayerViewController;
@interface MenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> 

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIView *playerHolder;
@property (strong, nonatomic) UINavigationController *playerNavController;
@property (strong, nonatomic) PlayerViewController *playerController;
@property (strong, nonatomic) NSMutableArray *cellContents;
@property (nonatomic) BOOL isFirstLoad;
@property (nonatomic) NSUInteger lastSelectedRow;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)loadCellContents;
- (void)showHome;
- (void)showSettings;

- (void)toggleOfflineMode;

@end
