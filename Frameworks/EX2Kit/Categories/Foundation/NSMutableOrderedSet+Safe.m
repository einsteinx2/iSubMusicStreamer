//
//  NSMutableOrderedSet+Safe.m
//  EX2Kit
//
//  Created by Benjamin Baron on 8/7/13.
//
//

#import "NSMutableOrderedSet+Safe.h"

@implementation NSMutableOrderedSet (Safe)

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

+ (id)orderedSetWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self orderedSetWithArray:array];
    }
    return [self orderedSetWithCapacity:0];
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
