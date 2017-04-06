//
//  NSArray+Safe.m
//  EX2Kit
//
//  Created by Ben Baron on 2/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSArray+Safe.h"

@implementation NSArray (Safe)

- (id)objectAtIndexSafe:(NSUInteger)index
{
	if ([self count] > index)
		return [self objectAtIndex:index];
	
	return nil;
}

+ (id)arrayWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self arrayWithArray:array];
    }
    return [self array];
}

- (id)initWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self initWithArray:array];
    }
    return [self init];
}

@end
