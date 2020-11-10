//
//  UIButton+StretchBackground.m
//  EX2Kit
//
//  Created by Benjamin Baron on 4/2/13.
//
//

#import "UIButton+StretchBackground.h"
#import "UIImage+CustomStretch.h"

@implementation UIButton (StretchBackground)

- (void)makeBackgroundResizableWithEdgeInsets:(UIEdgeInsets)edgeInsets
{
    [self setBackgroundImage:[[self backgroundImageForState:UIControlStateNormal] resizableImageWithCapInsetsBackport:edgeInsets] forState:UIControlStateNormal];
    [self setBackgroundImage:[[self backgroundImageForState:UIControlStateDisabled] resizableImageWithCapInsetsBackport:edgeInsets] forState:UIControlStateDisabled];
    [self setBackgroundImage:[[self backgroundImageForState:UIControlStateSelected] resizableImageWithCapInsetsBackport:edgeInsets] forState:UIControlStateSelected];
    [self setBackgroundImage:[[self backgroundImageForState:UIControlStateHighlighted] resizableImageWithCapInsetsBackport:edgeInsets] forState:UIControlStateHighlighted];
}

@end
