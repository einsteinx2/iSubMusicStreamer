//
//  UIImage+Tint.m
//  EX2Kit
//
//  Created by Ben Baron on 5/11/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//
// From: http://mbigatti.wordpress.com/2012/04/02/objc-an-uiimage-category-to-tint-images-with-transparency/

#import "UIImage+Tint.h"
#import "EX2Macros.h"

@implementation UIImage (Tint)

- (UIImage *)imageWithTint:(UIColor *)tintColor 
{
    // Begin drawing
    //CGRect aRect = CGRectMake(0.f, 0.f, self.size.width * SCREEN_SCALE(), self.size.height * SCREEN_SCALE());
    CGRect aRect = CGRectMake(0.f, 0.f, self.size.width, self.size.height);
    CGImageRef alphaMask;
	
    //
    // Compute mask flipping image
    //
    {
        //UIGraphicsBeginImageContext(aRect.size);
        UIGraphicsBeginImageContextWithOptions(aRect.size, NO, SCREEN_SCALE());
        CGContextRef c = UIGraphicsGetCurrentContext(); 
		
        // draw image
        CGContextTranslateCTM(c, 0, aRect.size.height);
        CGContextScaleCTM(c, 1.0, -1.0);
        [self drawInRect: aRect];
		
        alphaMask = CGBitmapContextCreateImage(c);
		
        UIGraphicsEndImageContext();
    }
	
    //
    //UIGraphicsBeginImageContext(aRect.size);
    UIGraphicsBeginImageContextWithOptions(aRect.size, NO, SCREEN_SCALE());
	
    // Get the graphic context
    CGContextRef c = UIGraphicsGetCurrentContext(); 
	
    // Draw the image
    [self drawInRect:aRect];
	
    // Mask
    CGContextClipToMask(c, aRect, alphaMask);
	
    // Set the fill color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextSetFillColorSpace(c, colorSpace);
	
    // Set the fill color
    CGContextSetFillColorWithColor(c, tintColor.CGColor);
	
    UIRectFillUsingBlendMode(aRect, kCGBlendModeNormal);
	
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();    
	
    // Release memory
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(alphaMask);
	
    return img;
}

@end