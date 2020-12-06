//
//  CustomUITextView.m
//  iSub
//
//  Created by bbaron on 8/17/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITextView.h"

@implementation CustomUITextView

- (void)drawRect:(CGRect)rect  {
	UIGraphicsBeginImageContext(self.frame.size);
	
	CGContextRef currentContext = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(currentContext, 3.0); //or whatever width you want
	CGContextSetRGBStrokeColor(currentContext, 0.0, 0.0, 0.0, 1.0);
	
	CGRect myRect = CGContextGetClipBoundingBox(currentContext);
	
	CGContextStrokeRect(currentContext, myRect);
	UIImage *backgroundImage = (UIImage *)UIGraphicsGetImageFromCurrentImageContext();
	UIImageView *myImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
	[myImageView setImage:backgroundImage];
	[self addSubview:myImageView];
	
	UIGraphicsEndImageContext();
}

@end
