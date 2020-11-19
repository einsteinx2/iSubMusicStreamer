//
//  RootView.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h>

@class MenuViewController;

@interface iPadRootViewController : UIViewController 

@property (strong) UIView* rootView;
@property (strong) UIView* menuView;
@property (strong) UIView* contentView;

@property (strong) UINavigationController *currentContentNavigationController;

@property (strong) MenuViewController* menuViewController;

- (void)switchContentViewController:(UIViewController *)controller;

@end
