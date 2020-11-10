//
//  UIButton+Colors.m
//  EX2Kit
//
//  Created by Benjamin Baron on 9/20/13.
//
//

#import "UIButton+Colors.h"
#import "UIImage+Color.h"

@implementation UIButton (Colors)

- (void)setBackgroundWithUnpressedColor:(UIColor *)unpressedColor pressedColor:(UIColor *)pressedColor
{
    UIImage *unpressedImage = [UIImage imageWithColor:unpressedColor];
    UIImage *pressedImage = [UIImage imageWithColor:pressedColor];
    
    [self setBackgroundImage:unpressedImage forState:UIControlStateNormal];
    [self setBackgroundImage:unpressedImage forState:UIControlStateDisabled];
    [self setBackgroundImage:pressedImage forState:UIControlStateHighlighted];
    [self setBackgroundImage:pressedImage forState:UIControlStateSelected];
}

@end
