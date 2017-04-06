//
//  EX2GlowButton.m
//  EX2Kit
//
//  Created by Benjamin Baron on 5/21/13.
//
//

#import "EX2GlowButton.h"

#import "UIView+Glow.h"

@implementation EX2GlowButton

- (void)setup
{
    _glowColor = UIColor.whiteColor;
    _fromIntensity = 1.;
    _toIntensity = 1.;
    _radius = 20.;
    _overdub = 2;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setup];
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    [self startGlowingWithColor:self.glowColor
                  fromIntensity:self.fromIntensity
                    toIntensity:self.toIntensity
                         radius:self.radius
                        overdub:self.overdub
                       animated:NO
                         repeat:NO];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self stopGlowingAnimated:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    [self stopGlowingAnimated:YES];
}

@end
