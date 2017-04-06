//
//  UIView+Glow.m
//
//  Created by Jon Manning on 29/05/12.
//  Copyright (c) 2012 Secret Lab. All rights reserved.
//
//  --------------------------------------------
//
//  Modified by Ben Baron for EX2Kit
//

#import <UIKit/UIKit.h>

@interface UIView (Glow)

@property (nonatomic, readonly) UIView* glowView;

// Fade up, then down.
- (void) glowOnce;

// Useful for indicating "this object should be over there"
- (void) glowOnceAtLocation:(CGPoint)point inView:(UIView*)view;

- (void) startGlowing;
- (void) startGlowingAnimated:(BOOL)animated;
- (void) startGlowingWithColor:(UIColor *)color intensity:(CGFloat)intensity animated:(BOOL)animated;
- (void) startGlowingWithColor:(UIColor*)color fromIntensity:(CGFloat)fromIntensity toIntensity:(CGFloat)toIntensity radius:(CGFloat)radius overdub:(NSUInteger)overdub animated:(BOOL)animated repeat:(BOOL)repeat;

- (void) stopGlowingAnimated:(BOOL)animated;

@end
