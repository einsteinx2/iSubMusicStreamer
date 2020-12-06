//
//  UIView+ObjCFrameHelper.m
//  EX2Kit
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UIView+ObjCFrameHelper.h"
#import "UIApplication+Helper.h"

@implementation UIView (ObjCFrameHelper)

- (CGFloat)x {
    return CGRectGetMinX(self.frame);
}

- (void)setX:(CGFloat)x {
    if (!isfinite(x)) return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.x = x;
	self.frame = newFrame;
}

- (CGFloat)y {
    return CGRectGetMinY(self.frame);
}

- (void)setY:(CGFloat)y {
    if (!isfinite(y)) return;
    
	CGRect newFrame = self.frame;
	newFrame.origin.y = y;
	self.frame = newFrame;
}

- (CGPoint)origin {
	return self.frame.origin;
}

- (void)setOrigin:(CGPoint)origin {
	if (!isfinite(origin.x) || !isfinite(origin.y)) return;
	
	CGRect newFrame = self.frame;
	newFrame.origin = origin;
	self.frame = newFrame;
}

- (CGFloat)width {
	return CGRectGetWidth(self.frame);
}

- (void)setWidth:(CGFloat)width {
    if (!isfinite(width)) return;
    
	CGRect newFrame = self.frame;
	newFrame.size.width = width;
	self.frame = newFrame;
}

- (CGFloat)height {
	return CGRectGetHeight(self.frame);
}

- (void)setHeight:(CGFloat)height {
    if (!isfinite(height)) return;
    
	CGRect newFrame = self.frame;
	newFrame.size.height = height;
	self.frame = newFrame;
}

- (CGSize)size {
	return self.frame.size;
}

- (void)setSize:(CGSize)size {
	if (!isfinite(size.width) || !isfinite(size.height)) return;
	
	CGRect newFrame = self.frame;
	newFrame.size = size;
	self.frame = newFrame;
}

@end
