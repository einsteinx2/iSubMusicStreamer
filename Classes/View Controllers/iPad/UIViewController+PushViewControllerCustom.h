//
//  UIViewController+PushViewControllerCustom.h
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

#define ISMSiPadViewWidth 387.
//448.

@interface UIViewController (PushViewControllerCustom)

- (void)pushViewControllerCustom:(UIViewController *)viewController;
- (void)pushViewControllerCustomWithNavControllerOnIpad:(UIViewController *)viewController;

- (void)showPlayer;

@end
