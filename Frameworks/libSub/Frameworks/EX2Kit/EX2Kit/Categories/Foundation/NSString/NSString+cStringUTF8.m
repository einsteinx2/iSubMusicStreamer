//
//  NSString+cStringUTF8.m
//  EX2Kit
//
//  Created by Ben Baron on 11/17/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+cStringUTF8.h"

@implementation NSString (cStringUTF8)

- (const char *)cStringUTF8
{
	return [self cStringUsingEncoding:NSUTF8StringEncoding];
}

@end
