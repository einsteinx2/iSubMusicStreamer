//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Benjamin Baron on 10/18/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"
#import "SavedSettings.h"
#import "ViewObjectsSingleton.h"
#import "Swift.h"

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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [viewObjectsS orderMainTabBarController];
    
    [self.class customizeMoreTabTableView:self];
}

@end
