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

    // Set the back gesture delegate to ourself
    __weak CustomUINavigationController *weakSelf = self;
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.delegate = weakSelf;
        self.delegate = weakSelf;
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Hijack the push method to disable the gesture
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    
    [super pushViewController:viewController animated:animated];
}

#pragma mark UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Prevent view controllers from going under the navigation bar
    viewController.edgesForExtendedLayout = UIRectEdgeNone;
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animate {
    // Enable the gesture again once the new controller is shown
    // TODO: Why did I do this years ago? lol
    self.interactivePopGestureRecognizer.enabled = YES;
}

@end
