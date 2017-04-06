//
//  UIViewController+PushViewControllerCustom.m
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "iPhoneStreamingPlayerViewController.h"

@implementation UIViewController (PushViewControllerCustom)

- (void)pushViewControllerCustom:(UIViewController *)viewController
{
	if (IS_IPAD())
	{
		viewController.view.width = ISMSiPadViewWidth;
		viewController.view.layer.cornerRadius = ISMSiPadCornerRadius;
		viewController.view.layer.masksToBounds = YES;
		StackScrollViewController *stack = [iSubAppDelegate sharedInstance].ipadRootViewController.stackScrollViewController;
		[stack addViewInSlider:viewController invokeByController:self isStackStartView:NO];
	}
	else
	{
        if ([self isKindOfClass:[UINavigationController class]])
            [(UINavigationController *)self pushViewController:viewController animated:YES];
        else
            [self.navigationController pushViewController:viewController animated:YES];
	}
}

- (void)pushViewControllerCustomWithNavControllerOnIpad:(UIViewController *)viewController
{
	if (IS_IPAD())
	{
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewController];
		nav.navigationBar.tintColor = [UIColor blackColor];
		
		viewController.view.width = ISMSiPadViewWidth;
		[self pushViewControllerCustom:nav];
	}
	else
	{
		[self pushViewControllerCustom:viewController];
	}
}

- (void)showPlayer
{
	// Show the player
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	}
}

@end
