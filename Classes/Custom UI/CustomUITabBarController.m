//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Benjamin Baron on 10/18/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"
#import "SavedSettings.h"

@implementation CustomUITabBarController

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && UIDevice.currentDevice.orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

//- (void)viewWillLayoutSubviews {
//    [super viewWillLayoutSubviews];
//    
//    CGRect tabBarFrame = self.tabBar.frame;
//    tabBarFrame.size.height = 100;
//    self.tabBar.frame = tabBarFrame;
//}

//- (void)viewDidLoad {
//    [super viewDidLoad];
//
//    self.tabBar.backgroundImage = [[UIImage alloc] init];
//    self.tabBar.barTintColor = UIColor.clearColor;
//    self.tabBar.translucent = YES;
//
//    // Add blur effect
//    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
//    blurView.frame = self.tabBar.bounds;
//    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//    [self.tabBar insertSubview:blurView atIndex:0];
//}

@end
