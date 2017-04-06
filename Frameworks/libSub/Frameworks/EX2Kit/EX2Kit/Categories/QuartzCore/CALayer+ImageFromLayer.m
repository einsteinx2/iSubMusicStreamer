//
//  CALayer+ImageFromLayer.m
//  EX2Kit
//
//  Created by Ben Baron on 2/28/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "CALayer+ImageFromLayer.h"

@implementation CALayer (ImageFromLayer)

- (UIImage *)imageFromLayer
{
	UIGraphicsBeginImageContext([self frame].size);
	
	[self renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	return outputImage;
}

@end
