//
//  UIButton+Colors.h
//  EX2Kit
//
//  Created by Benjamin Baron on 9/20/13.
//
//

#import <UIKit/UIKit.h>

@interface UIButton (Colors)

// Method to style a UIButton with solid colors. Creates a 1px image of the color and
// sets as the background image.
- (void)setBackgroundWithUnpressedColor:(UIColor *)unpressedColor pressedColor:(UIColor *)pressedColor;

@end
