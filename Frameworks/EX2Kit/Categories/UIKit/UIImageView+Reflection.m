//
//  UIImageView+Reflection.m
//  EX2Kit
//
//  Created by Ben Baron on 2/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIImageView+Reflection.h"
#import "UIImage+Reflection.h"

@implementation UIImageView (Reflection)

- (UIImage *)reflectedImageWithHeight:(CGFloat)height
{
    return [self.image reflectedImageWithHeight:height];
}

@end
