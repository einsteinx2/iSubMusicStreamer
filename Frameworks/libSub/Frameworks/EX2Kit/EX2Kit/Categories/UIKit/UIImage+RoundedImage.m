//
//  UIImage+RoundedImage.m
//  EX2Kit
//
//  Created by Justin Hill on 2/13/14.
//
//

#import "UIImage+RoundedImage.h"

@implementation UIImage (RoundedImage)

- (UIImage *)circleImage
{
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, self.size.width, self.size.height);
    imageLayer.contents = (id) self.CGImage;
    
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = self.size.width / 2.;
    
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return roundedImage;
}

@end
