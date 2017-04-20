//
//  NSMutableArray+Safe.m
//  EX2Kit
//
//  Created by Ben Baron on 6/11/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSMutableArray+Safe.h"

@implementation NSMutableArray (Safe)

- (void)addObjectSafe:(id)object
{
    if (object)
    {
        [self addObject:object];
    }
}

- (void)insertObjectSafe:(id)object atIndex:(NSUInteger)index
{
    if (object)
    {
        if (index > self.count)
            index = self.count;
        
        [self insertObject:object atIndex:index];
    }
}

- (void)removeObjectAtIndexSafe:(NSUInteger)index
{
	if (index < self.count)
	{
		[self removeObjectAtIndex:index];
	}
}

- (void)removeObjectSafe:(id)object
{
	if (object)
	{
		[self removeObject:object];
	}
}

- (void)addObjectsFromArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        [self addObjectsFromArray:array];
    }
}

+ (id)arrayWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self arrayWithArray:array];
    }
    return [self arrayWithCapacity:0];
}

- (id)initWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self initWithArray:array];
    }
    return [self initWithCapacity:0];
}

@end
