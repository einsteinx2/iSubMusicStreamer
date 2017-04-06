//
//  UIView+AutoLayout.h
//  Anghami
//
//  Created by Justin Hill on 4/15/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (AutoLayout)

- (void)autolayoutFillSuperview;
- (void)autolayoutCenterInParentHMultiplier:(float)hMultiplier hConstant:(float)hConstant vMultiplier:(float)vMultiplier vConstant:(float)vConstant;
- (NSLayoutConstraint *)autolayoutCenterHorizontallyInParent;
- (NSLayoutConstraint *)autolayoutCenterHorizontallyInParentMultiplier:(float)multiplier;
- (NSLayoutConstraint *)autolayoutWidthProportionalToParentWidth:(float)proportion constant:(float)constant;
- (NSLayoutConstraint *)autolayoutHeightProportionalToParentHeight:(float)proportion constant:(float)constant;
- (NSLayoutConstraint *)autolayoutHeightProportionalToWidth:(float)proportion constant:(float)constant;
- (NSLayoutConstraint *)autolayoutPinEdge:(NSLayoutAttribute)edge toParentEdge:(NSLayoutAttribute)parentEdge constant:(float)constant;
- (NSLayoutConstraint *)autolayoutPinToEdgeOfParent:(NSLayoutAttribute)edge constant:(float)constant;
- (NSLayoutConstraint *)autolayoutPinEdge:(NSLayoutAttribute)edge toEdge:(NSLayoutAttribute)otherEdge ofSibling:(UIView *)sibling constant:(float)constant;
- (NSLayoutConstraint *)autolayoutSetAttribute:(NSLayoutAttribute)attribute toConstant:(float)constant;

- (void)removeAllConstraints;
@end
