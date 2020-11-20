//
//  RootView.m
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
#import "CustomUINavigationController.h"
//#import "ViewObjectsSingleton.h"

@implementation iPadRootViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    // Add black background to status bar DOESN'T WORK...
//    UIView *statusBarBackground = [[UIView alloc] initWithFrame:UIApplication.keyWindow.windowScene.statusBarManager.statusBarFrame];
//    statusBarBackground.backgroundColor = UIColor.blackColor;
//    [UIApplication.keyWindow addSubview:statusBarBackground];
////    [UIApplication.keyWindow insertSubview:statusBarBackground atIndex:0];
	
	self.rootView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	self.rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
	[self.rootView setBackgroundColor:[UIColor clearColor]];
	
	self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, self.view.frame.size.height)];
	self.menuView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	self.menuViewController = [[MenuViewController alloc] initWithFrame:CGRectMake(0, 0, self.menuView.frame.size.width, self.menuView.frame.size.height)];
	[self.menuViewController.view setBackgroundColor:[UIColor clearColor]];
	[self.menuViewController viewWillAppear:NO];
	[self.menuViewController viewDidAppear:NO];
	[self.menuView addSubview:self.menuViewController.view];
	
	self.contentView = [[UIView alloc] initWithFrame:CGRectMake(self.menuView.frame.size.width, 0, self.rootView.frame.size.width - self.menuView.frame.size.width, self.rootView.frame.size.height)];
	self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
	
	[self.rootView addSubview:self.menuView];
	[self.rootView addSubview:self.contentView];
	self.view.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.7];
	[self.view addSubview:self.rootView];
    
    // On iOS 7, don't let the status bar text cover the content
    self.rootView.height -= 20.;
    self.rootView.y += 20.;
}

- (void)switchContentViewController:(UIViewController *)controller {
    [self.currentContentNavigationController.view removeFromSuperview];
    [self.currentContentNavigationController removeFromParentViewController];
    
    UINavigationController *navController = [[CustomUINavigationController alloc] initWithRootViewController:controller];
    navController.view.frame = self.contentView.bounds;
    navController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//    navController.navigationBar.backgroundColor = viewObjectsS.windowColor;
    [self addChildViewController:navController];
    [self.contentView addSubview:navController.view];
    
    self.currentContentNavigationController = navController;
}

@end
