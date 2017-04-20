//
//  EX2Kit.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/22/12.
//
//

#import "EX2Kit.h"

@implementation EX2Kit

static __strong NSBundle *_resourceBundle;

+ (void)initialize
{
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"EX2KitResources" ofType:@"bundle"];
    _resourceBundle = [NSBundle bundleWithPath:bundlePath];
}

+ (NSBundle *)resourceBundle
{
    return _resourceBundle;
}

@end
