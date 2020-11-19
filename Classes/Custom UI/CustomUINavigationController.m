//
//  CustomUINavigationController.m
//  iSub
//
//  Created by Benjamin Baron on 10/19/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//
// Fix for iOS 7 back gesture detailed here: http://keighl.com/post/ios7-interactive-pop-gesture-custom-back-button/

#import "CustomUINavigationController.h"
#import "SavedSettings.h"

@implementation CustomUINavigationController

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Make ourselves our own delegate to automatically fix view controllers going under the navigation bar
    self.delegate = self;
}

#pragma mark UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Prevent view controllers from going under the navigation bar
    viewController.edgesForExtendedLayout = UIRectEdgeNone;
}

@end
