//
//  UIViewController+PushViewControllerCustom.m
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "Defines.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation UIViewController (PushViewControllerCustom)

- (void)pushViewControllerCustom:(UIViewController *)viewController {
    if ([self isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)self pushViewController:viewController animated:YES];
    } else {
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)showPlayer {
	// Show the player
	if (UIDevice.isPad) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	} else {
        PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
        playerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:playerViewController animated:YES];
	}
}

@end
