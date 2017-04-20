//
//  UIBezierCurve+Smoothing.h
//  EX2Kit
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIBezierPath (Smoothing)

- (UIBezierPath *)smoothedPathWithGranularity:(NSInteger)granularity;

@end
