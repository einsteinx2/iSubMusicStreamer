//
//  UIImage+Color.m
//  EX2Kit
//
//  Created by Benjamin Baron on 9/19/13.
//
//

#import "UIImage+Color.h"

@implementation UIImage (Color)

// Adapted from here: http://stackoverflow.com/a/993159/299262
+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
