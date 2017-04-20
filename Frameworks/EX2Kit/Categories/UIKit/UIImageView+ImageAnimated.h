//
//  UIImageView+ImageAnimated.h
//  EX2Kit
//
//  Created by Benjamin Baron on 9/3/13.
//
//

#import <UIKit/UIKit.h>

@interface UIImageView (ImageAnimated)

- (void)setImageWithFade:(UIImage *)image;
- (void)setImage:(UIImage *)image animationType:(NSString *)animationType duration:(NSTimeInterval)duration;

@end
