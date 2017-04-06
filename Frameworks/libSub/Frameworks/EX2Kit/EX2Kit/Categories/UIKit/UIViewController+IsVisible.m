//
//  UIViewController+IsVisible.m
//  EX2Kit
//
//  Created by Ben Baron on 3/10/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIViewController+IsVisible.h"

@implementation UIViewController (IsVisible)

// http://stackoverflow.com/questions/2777438/how-to-tell-if-uiviewcontrollers-view-is-visible
// The view's window property is non-nil if a view is currently visible
- (BOOL)isVisible
{
	return (self.isViewLoaded && self.view.window);
}

@end
