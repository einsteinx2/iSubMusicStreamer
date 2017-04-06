//
//  NSArray+FirstObject.m
//  EX2Kit
//
//  Created by Ben Baron on 11/16/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSArray+FirstObject.h"

@implementation NSArray (FirstObject)

- (id)firstObjectSafe
{
	return [self objectAtIndexSafe:0];
}

@end
