//
//  EX2LargerTouchScrollView.m
//  EX2Kit
//
//  Created by Benjamin Baron on 5/10/13.
//
//

#import "EX2LargerTouchScrollView.h"

@interface EX2LargerTouchScrollView()
// Only used with touchAreaPadding
@property (nonatomic) CGRect touchFrameInWindow;
@end

@implementation EX2LargerTouchScrollView

- (void)setup
{
    _touchAreaPadding = UIEdgeInsetsZero;
    _touchFrameInWindow = [self convertRect:self.frame toView:[[UIApplication sharedApplication] keyWindow]];
    self.scrollsToTop = NO;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setup];
    }
    return self;
}

- (void)setTouchAreaPadding:(UIEdgeInsets)touchAreaPadding
{
    // Calculate the new touch frame
    CGRect rectInWindow = [self convertRect:self.frame toView:[[UIApplication sharedApplication] keyWindow]];
    
    rectInWindow.origin.y -= touchAreaPadding.top;
    rectInWindow.size.height += touchAreaPadding.top;
    
    rectInWindow.origin.x -= touchAreaPadding.left;
    rectInWindow.size.width += touchAreaPadding.left;
    
    rectInWindow.size.height += touchAreaPadding.bottom;
    
    rectInWindow.size.width += touchAreaPadding.right;
    
    self.touchFrameInWindow = rectInWindow;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    // If we're not matching the superview's touch area, and we have no padding set, then act like a regular scrollview
    if (!self.isTouchAreaFillsSuperview && UIEdgeInsetsEqualToEdgeInsets(self.touchAreaPadding, UIEdgeInsetsZero))
        return [super pointInside:point withEvent:event];
    
    if (self.isTouchAreaFillsSuperview)
    {
        // Make the touch area cover the whole parent view
        CGPoint parentLocation = [self convertPoint:point toView:self.superview];
        return CGRectContainsPoint(self.superview.bounds, parentLocation);
    }
	else
    {
        // Make the touch area equal our frame plus the padding (not tested yet)
        CGPoint windowLocation = [self convertPoint:point toView:[[UIApplication sharedApplication] keyWindow]];
        return CGRectContainsPoint(self.touchFrameInWindow, windowLocation);
    }
}

@end
