//
//  UIView+Tools.m
//  EX2Kit
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UIView+Tools.h"
#import "CALayer+SublayerWithName.h"

@implementation UIView (Tools)

#define DEFAULT_SHADOW_ALPHA 0.5
#define DEFAULT_SHADOW_WIDTH 17.0

#define ISMSLeftShadowName @"ISMS Left Shadow"
#define ISMSRightShadowName @"ISMS Right Shadow"
#define ISMSTopShadowName @"ISMS Top Shadow"
#define ISMSBottomShadowName @"ISMS Bottom Shadow"

#define ISMSiPadCornerRadius 5.

+ (CAGradientLayer *)verticalShadowWithAlpha:(CGFloat)shadowAlpha inverse:(BOOL)inverse
{
	CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];
    newShadow.startPoint = CGPointMake(0, 0.5);
    newShadow.endPoint = CGPointMake(1.0, 0.5);
	CGColorRef darkColor  = (CGColorRef)CFRetain([UIColor colorWithWhite:0.0f alpha:shadowAlpha].CGColor);
	CGColorRef lightColor = (CGColorRef)CFRetain([UIColor clearColor].CGColor);
	newShadow.colors = @[(__bridge id)(inverse ? lightColor : darkColor), (__bridge id)(inverse ? darkColor : lightColor)];
    
    CFRelease(darkColor);
    CFRelease(lightColor);
	return newShadow;
}

- (void)addLeftShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha
{
	[self removeLeftShadow];
	
	CAGradientLayer *leftShadow = [UIView verticalShadowWithAlpha:shadowAlpha inverse:YES];
	leftShadow.frame = CGRectMake(-shadowWidth, 0, shadowWidth + ISMSiPadCornerRadius, 1024.);
	leftShadow.name = ISMSLeftShadowName;
	[self.layer insertSublayer:leftShadow atIndex:0];
}

- (void)addLeftShadow
{
	[self addLeftShadowWithWidth:DEFAULT_SHADOW_WIDTH alpha:DEFAULT_SHADOW_ALPHA];
}

- (void)removeLeftShadow
{
	[[self.layer sublayerWithName:ISMSLeftShadowName] removeFromSuperlayer];
}

- (void)addRightShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha
{
	[self removeRightShadow];
	
	CAGradientLayer *rightShadow = [UIView verticalShadowWithAlpha:shadowAlpha inverse:NO];
	rightShadow.frame = CGRectMake(self.width - ISMSiPadCornerRadius, 0, DEFAULT_SHADOW_WIDTH + ISMSiPadCornerRadius, 1024.);
	rightShadow.name = ISMSRightShadowName;
	[self.layer insertSublayer:rightShadow atIndex:0];
}

- (void)addRightShadow
{
	[self addRightShadowWithWidth:DEFAULT_SHADOW_WIDTH alpha:DEFAULT_SHADOW_ALPHA];
}

- (void)removeRightShadow
{
	[[self.layer sublayerWithName:ISMSRightShadowName] removeFromSuperlayer];
}

- (void)addBottomLine
{
    UIView *bottomLine = [[UIView alloc] init];
    bottomLine.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    bottomLine.frame = CGRectMake(0., self.height - 1., self.width, 1.);
    bottomLine.backgroundColor = [UIColor colorWithRed:200./255. green:199./255. blue:204./255. alpha:1.];
    [self addSubview:bottomLine];
}

+ (CAGradientLayer *)horizontalShadowWithAlpha:(CGFloat)shadowAlpha inverse:(BOOL)inverse
{
	CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];
    newShadow.startPoint = CGPointMake(0.5, 0);
    newShadow.endPoint = CGPointMake(0.5, 1.0);
	CGColorRef darkColor  = (CGColorRef)CFRetain([UIColor colorWithWhite:0.0f alpha:shadowAlpha].CGColor);
	CGColorRef lightColor = (CGColorRef)CFRetain([UIColor clearColor].CGColor);
	newShadow.colors = @[(__bridge id)(inverse ? lightColor : darkColor), (__bridge id)(inverse ? darkColor : lightColor)];
    
    CFRelease(darkColor);
    CFRelease(lightColor);
	return newShadow;
}

- (void)addBottomShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha
{
	[self removeBottomShadow];
	
	CAGradientLayer *bottomShadow = [UIView horizontalShadowWithAlpha:shadowAlpha inverse:NO];
	bottomShadow.frame = CGRectMake(0, self.height, 1024., shadowWidth);
	bottomShadow.name = ISMSBottomShadowName;
	[self.layer insertSublayer:bottomShadow atIndex:0];
}

- (void)addBottomShadow
{
	[self addBottomShadowWithWidth:DEFAULT_SHADOW_WIDTH alpha:DEFAULT_SHADOW_ALPHA];
}

- (void)removeBottomShadow
{
	[[self.layer sublayerWithName:ISMSBottomShadowName] removeFromSuperlayer];
}

- (void)addTopShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha
{
	[self removeTopShadow];
	
	CAGradientLayer *topShadow = [UIView horizontalShadowWithAlpha:shadowAlpha inverse:YES];
	topShadow.frame = CGRectMake(0, 0 - shadowWidth, self.width, shadowWidth);
	topShadow.name = ISMSTopShadowName;
	[self.layer insertSublayer:topShadow atIndex:0];
}

- (void)addTopShadow
{
	[self addTopShadowWithWidth:DEFAULT_SHADOW_WIDTH alpha:DEFAULT_SHADOW_ALPHA];
}

- (void)removeTopShadow
{
	[[self.layer sublayerWithName:ISMSTopShadowName] removeFromSuperlayer];
}

- (CGFloat)left 
{
    return CGRectGetMinX(self.frame);
}

- (void)setLeft:(CGFloat)x 
{
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}

- (CGFloat)top 
{
    return CGRectGetMinY(self.frame);
}

- (void)setTop:(CGFloat)y 
{
    CGRect frame = self.frame;
    frame.origin.y = y;
    self.frame = frame;
}

- (CGFloat)right 
{
    return CGRectGetMaxX(self.frame);
}

- (void)setRight:(CGFloat)right 
{
    CGRect frame = self.frame;
    frame.origin.x = right - frame.size.width;
    self.frame = frame;
}

- (CGFloat)bottom 
{
	return CGRectGetMaxY(self.frame);
}

- (void)setBottom:(CGFloat)bottom 
{
    CGRect frame = self.frame;
    frame.origin.y = bottom - frame.size.height;
    self.frame = frame;
}

- (CGPoint)centerOfBounds
{
    return CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
}


- (CGFloat)x
{
	return self.left;;
}

- (void)setX:(CGFloat)x
{
    if (!isfinite(x))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.x = x;
	self.frame = newFrame;
}

- (CGFloat)y
{
	return self.top;
}

- (void)setY:(CGFloat)y
{
    if (!isfinite(y))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.y = y;
	self.frame = newFrame;
}

- (CGPoint)origin
{
	return self.frame.origin;
}

- (void)setOrigin:(CGPoint)origin
{
	if (!isfinite(origin.x) || !isfinite(origin.y))
		return;
	
	CGRect newFrame = self.frame;
	newFrame.origin = origin;
	self.frame = newFrame;
}

- (CGFloat)width
{
	return CGRectGetWidth(self.frame);
}

- (void)setWidth:(CGFloat)width
{
    if (!isfinite(width))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.size.width = width;
	self.frame = newFrame;
}

- (CGFloat)height
{
	return CGRectGetHeight(self.frame);
}

- (void)setHeight:(CGFloat)height
{
    if (!isfinite(height))
        return;
    
	CGRect newFrame = self.frame;
	newFrame.size.height = height;
	self.frame = newFrame;
}

- (CGSize)size
{
	return self.frame.size;
}

- (void)setSize:(CGSize)size
{
	if (!isfinite(size.width) || !isfinite(size.height))
		return;
	
	CGRect newFrame = self.frame;
	newFrame.size = size;
	self.frame = newFrame;
}

- (UIViewController *)viewController;
{
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) 
	{
        return nextResponder;
    } 
	else 
	{
        return nil;
    }
}

- (CGSize)realSizeDidRotate
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    CGSize size = self.frame.size;
    if ((UIInterfaceOrientationIsLandscape(orientation) && size.width < size.height) ||
        (UIInterfaceOrientationIsPortrait(orientation) && size.width > size.height))
    {
        // flip width and height
        CGFloat f = size.width;
        size.width = size.height;
        size.height = f;
    }
    return size;
}

// Convert the view for use in Arabic/Hebrew layout
- (void)convertToRTL
{
    for (UIView *subview in self.subviews)
    {
        // Adjust the position
        subview.right = subview.superview.width - subview.x;
        
        // Adjust the struts if necessary
        if (!(subview.autoresizingMask & UIViewAutoresizingFlexibleLeftMargin) && (subview.autoresizingMask & UIViewAutoresizingFlexibleRightMargin))
        {
            // If the view is locked to the left side, lock it to the right side
            subview.autoresizingMask &= ~UIViewAutoresizingFlexibleRightMargin;
            subview.autoresizingMask |= UIViewAutoresizingFlexibleLeftMargin;
        }
        else if (!(subview.autoresizingMask & UIViewAutoresizingFlexibleRightMargin) && (subview.autoresizingMask & UIViewAutoresizingFlexibleLeftMargin))
        {
            // If the view is locked to the right side, lock it to the left side
            subview.autoresizingMask &= ~UIViewAutoresizingFlexibleLeftMargin;
            subview.autoresizingMask |= UIViewAutoresizingFlexibleRightMargin;
        }
        
        // Switch the text alignment if necessary
        if ([subview isKindOfClass:[UILabel class]])
        {
            ((UILabel *)subview).textAlignment = NSTextAlignmentRight;
        }
    }
}

- (BOOL)isChildOfView:(UIView *)aView
{
    UIView *superview = self.superview;
    while (superview)
    {
        if (superview == aView)
        {
            return YES;
        }
        superview = superview.superview;
    }
    return NO;
}

- (BOOL)isChildOfViewType:(Class)aClass
{
    UIView *superview = self.superview;
    while (superview)
    {
        if ([superview isKindOfClass:aClass])
        {
            return YES;
        }
        superview = superview.superview;
    }
    return NO;
}

- (void)centerHorizontally
{
    [self centerHorizontallyInBounds:self.superview.bounds];
}

- (void)centerVertically
{
    [self centerVerticallyInBounds:self.superview.bounds];
}

- (void)centerHorizontallyAndVertically
{
    [self centerHorizontallyAndVerticallyInBounds:self.superview.bounds];
}

- (void)centerHorizontallyInBounds:(CGRect)bounds
{
    self.center = CGPointMake(bounds.size.width / 2., self.center.y);
}

- (void)centerVerticallyInBounds:(CGRect)bounds
{
    self.center = CGPointMake(self.center.x, bounds.size.height / 2.);
}

- (void)centerHorizontallyAndVerticallyInBounds:(CGRect)bounds
{
    self.center = CGPointMake(bounds.size.width / 2., bounds.size.height / 2.);
}

@end
