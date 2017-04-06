//
//  UIImage+Cropping.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/27/12.
//
//

#import "UIImage+Cropping.h"

@implementation UIImage (Cropping)

// Thanks to this SO answer: http://stackoverflow.com/a/712553/299262
- (UIImage *)croppedImage:(CGRect)cropFrame
{
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, cropFrame);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return croppedImage;
}

- (UIImage*)imageScaledDownToWidth:(float)i_width;
{
    if (self.size.width <= i_width)
        return self;
    
    float oldWidth = self.size.width;
    float scaleFactor = i_width / oldWidth;
    
    float newHeight = self.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
