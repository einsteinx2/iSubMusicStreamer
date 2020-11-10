//
//  NSOrderedSet+FilterBlock.m
//  EX2Kit
//
//  Created by Benjamin Baron on 9/6/13.
//
//

#import "NSOrderedSet+FilterBlock.h"
#import "NSOrderedSet+Safe.h"

@implementation NSOrderedSet (FilterBlock)

- (NSOrderedSet *)filteredOrderedSetUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate
{
    NSIndexSet *filteredIndexes = [self indexesOfObjectsPassingTest:predicate];
    return [NSOrderedSet orderedSetWithArraySafe:[self objectsAtIndexes:filteredIndexes]];
}

@end
