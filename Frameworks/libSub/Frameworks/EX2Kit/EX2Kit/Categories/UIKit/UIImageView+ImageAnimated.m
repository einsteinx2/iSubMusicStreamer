//
//  UIImageView+ImageAnimated.m
//  EX2Kit
//
//  Created by Benjamin Baron on 9/3/13.
//
//

#import "UIImageView+ImageAnimated.h"

@implementation UIImageView (ImageAnimated)

- (void)setImageWithFade:(UIImage *)image
{
    [self setImage:image animationType:kCATransitionFade duration:.2];
}

- (void)setImage:(UIImage *)image animationType:(NSString *)animationType duration:(NSTimeInterval)duration
{
    CATransition *animation = [CATransition animation];
    animation.duration = duration;
    animation.type = animationType;
    [self.layer addAnimation:animation forKey:@"imageFade"];
    self.image = image;
}

@end
