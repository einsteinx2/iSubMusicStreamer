//
//  UIViewController+Tools.h
//  EX2Kit
//
//  Created by Justin Hill on 11/7/13.
//
//

#import <UIKit/UIKit.h>

@interface UIViewController (Tools)

- (void)insertAsChildViewController:(UIViewController *)viewController;
- (void)removeFromParentContainerViewController;

@end
