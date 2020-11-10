//
//  ContainerView.m
//  iSub
//
//  Created by Ben Baron on 2/21/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "StackContainerView.h"

@implementation StackContainerView

- (void)setup
{
	self.userInteractionEnabled = YES;

	[self addLeftShadowWithWidth:5. alpha:.5];
	//[self addRightShadowWithWidth:2. alpha:.25];
}

- (id)init
{
	if ((self = [super init]))
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

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		[self setup];
	}
	return self;
}

- (UIView *)insideView
{
	return [self.subviews firstObjectSafe];
}

/* 
 * Pass all touch events along to the inside view 
 */

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
    [self.nextResponder touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.nextResponder touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.nextResponder touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.nextResponder touchesCancelled:touches withEvent:event];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event 
{
	UIView *insideView = self.insideView;
    return [insideView hitTest:[self convertPoint:point toView:insideView] withEvent:event];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event 
{
	UIView *insideView = self.insideView;
    return [insideView pointInside:[self convertPoint:point toView:insideView] withEvent:event];
}

@end
