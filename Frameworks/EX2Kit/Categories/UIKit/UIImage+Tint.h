//
//  UIImage+Tint.h
//  EX2Kit
//
//  Created by Ben Baron on 5/11/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//
// From: http://mbigatti.wordpress.com/2012/04/02/objc-an-uiimage-category-to-tint-images-with-transparency/

#import <UIKit/UIKit.h>

@interface UIImage (Tint)

- (UIImage *)imageWithTint:(UIColor *)tintColor;

@end