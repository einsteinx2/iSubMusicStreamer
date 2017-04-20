//
//  UIWebView+HideShadows.m
//  EX2Kit
//
//  Created by Benjamin Baron on 3/11/13.
//
//

#import "UIWebView+HideShadows.h"

@implementation UIWebView (HideShadows)

- (void)hideOrShowShadows:(BOOL)hidden
{
    for (UIView *wview in [[[self subviews] objectAtIndexSafe:0] subviews])
    {
        // Assume that the image views are the shadows
        if ([wview isKindOfClass:[UIImageView class]])
        {
            wview.hidden = hidden;
        }
    }
}

- (void)hideShadows
{
    [self hideOrShowShadows:YES];
}

- (void)showShadows
{
    [self hideOrShowShadows:NO];
}

@end
