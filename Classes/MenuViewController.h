//
//  MenuViewController.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h> 

@class iPhoneStreamingPlayerViewController;
@interface MenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> 

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIView *playerHolder;
@property (strong, nonatomic) UINavigationController *playerNavController;
@property (strong, nonatomic) iPhoneStreamingPlayerViewController *playerController;
@property (strong, nonatomic) NSMutableArray *cellContents;
@property (nonatomic) BOOL isFirstLoad;
@property (nonatomic) NSUInteger lastSelectedRow;

- (id)initWithFrame:(CGRect)frame;
- (void)loadCellContents;
- (UIView *)createHeaderView:(BOOL)withImage;
- (UIView *)createFooterView;
- (void)showHome;
- (void)showSettings;

- (void)toggleOfflineMode;

@end
