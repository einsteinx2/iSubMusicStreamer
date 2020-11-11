//
//  CellCachedIndicatorView.m
//  iSub
//
//  Created by Benjamin Baron on 11/9/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "CellCachedIndicatorView.h"
#import "ViewObjectsSingleton.h"

@implementation CellCachedIndicatorView

- (instancetype)init {
    return [self initWithSize:20];
}

// TODO: Flip for RTL
- (instancetype)initWithSize:(CGFloat)size {
    if (self = [super initWithFrame:CGRectMake(0, 0, size, size)]) {
        UIBezierPath *maskPath = [UIBezierPath bezierPath];
        [maskPath moveToPoint:CGPointMake(0, 0)];
        [maskPath addLineToPoint:CGPointMake(size, 0)];
        [maskPath addLineToPoint:CGPointMake(0, size)];
        [maskPath closePath];

        CAShapeLayer *triangleMaskLayer = [CAShapeLayer layer];
        [triangleMaskLayer setPath:maskPath.CGPath];

        self.backgroundColor = viewObjectsS.currentLightColor;
        self.layer.mask = triangleMaskLayer;
        self.hidden = YES;
    }
    return self;
}

@end
