//
//  UIView+SetNeedsLayoutSafe.m
//  EX2Kit
//
//  Created by Benjamin Baron on 7/17/13.
//
//

#import "UIView+SetNeedsLayoutSafe.h"
#import "EX2Dispatch.h"

@implementation UIView (SetNeedsLayoutSafe)

- (void)setNeedsLayoutSafe
{
    if ([NSThread isMainThread])
    {
        [self setNeedsLayout];
    }
    else
    {
        [EX2Dispatch runInMainThreadAsync:^{ [self setNeedsLayout]; }];
    }
}

- (void)setNeedsDisplaySafe
{
    if ([NSThread isMainThread])
    {
        [self setNeedsDisplay];
    }
    else
    {
        [EX2Dispatch runInMainThreadAsync:^{ [self setNeedsDisplay]; }];
    }
}

- (void)setNeedsDisplayInRectSafe:(CGRect)rect
{
    if ([NSThread isMainThread])
    {
        [self setNeedsDisplayInRect:rect];
    }
    else
    {
        [EX2Dispatch runInMainThreadAsync:^{ [self setNeedsDisplayInRect:rect]; }];
    }
}

@end
