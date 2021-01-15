//
//  UIViewController+PushViewControllerCustom.h
//  iSub
//
//  Created by Ben Baron on 2/20/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (PushViewControllerCustom)

- (void)pushViewControllerCustom:(UIViewController *)viewController;
- (void)showPlayer;

@end

NS_ASSUME_NONNULL_END
