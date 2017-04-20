//
//  NSOrderedSet+Safe.m
//  EX2Kit
//
//  Created by Benjamin Baron on 8/7/13.
//
//

#import "NSOrderedSet+Safe.h"

@implementation NSOrderedSet (Safe)

- (id)objectAtIndexSafe:(NSUInteger)index
{
	if ([self count] > index)
		return [self objectAtIndex:index];
	
	return nil;
}

+ (id)orderedSetWithArraySafe:(NSArray *)array
{
    if (array.count > 0)
    {
        return [self orderedSetWithArray:array];
    }
    return [self orderedSet];
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
