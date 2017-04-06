//
//  UIViewController+Tools.m
//  EX2Kit
//
//  Created by Justin Hill on 11/7/13.
//
//

#import "UIViewController+Tools.h"

@implementation UIViewController (Tools)

- (void)insertAsChildViewController:(UIViewController *)viewController
{
    [self addChildViewController: viewController];
    [self.view addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
}

- (void)removeFromParentContainerViewController
{
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
}

@end
