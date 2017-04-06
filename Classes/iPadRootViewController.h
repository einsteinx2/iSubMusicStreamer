//
//  RootView.h
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import <UIKit/UIKit.h>


@class MenuViewController;
@class StackScrollViewController;

@class UIViewExt;

@interface iPadRootViewController : UIViewController 

@property (strong) UIViewExt* rootView;
@property (strong) UIView* leftMenuView;
@property (strong) UIView* rightSlideView;

@property (strong) MenuViewController* menuViewController;
@property (strong) StackScrollViewController* stackScrollViewController;


@end
