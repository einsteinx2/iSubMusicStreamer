//
//  UIImage+Cropping.h
//  EX2Kit
//
//  Created by Benjamin Baron on 10/27/12.
//
//

#import <UIKit/UIKit.h>

@interface UIImage (Cropping)

- (UIImage *)croppedImage:(CGRect)cropFrame;

- (UIImage*)imageScaledDownToWidth:(float)width;

@end
