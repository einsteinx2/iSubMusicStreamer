//
//  UIApplication+Orientiation.m
//  iSub
//
//  Created by Benjamin Baron on 11/9/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "UIApplication+Orientiation.h"

@implementation UIApplication (Orientiation)

+ (UIInterfaceOrientation)orientation {
    return [[[[[UIApplication sharedApplication] windows] firstObject] windowScene] interfaceOrientation];
}

@end
