//
//  UIColor+ColorWithInt.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/8/13.
//
//

#import "UIColor+ColorWithInt.h"

@implementation UIColor (ColorWithInt)

+ (UIColor *)colorWithRedInt:(NSUInteger)red greenInt:(NSUInteger)green blueInt:(NSUInteger)blue alpha:(CGFloat)alpha
{
    return [self colorWithRed:(float)red/255.
                        green:(float)green/255.
                         blue:(float)blue/255.
                        alpha:alpha];
}

@end
