//
//  UIView+SetNeedsLayoutSafe.h
//  EX2Kit
//
//  Created by Benjamin Baron on 7/17/13.
//
//

#import <UIKit/UIKit.h>

@interface UIView (SetNeedsLayoutSafe)

// Used to guarantee that setNeedsLayout/Display runs on the main thread, to prevent UIKit crashes
- (void)setNeedsLayoutSafe;
- (void)setNeedsDisplaySafe;
- (void)setNeedsDisplayInRectSafe:(CGRect)rect;

@end
