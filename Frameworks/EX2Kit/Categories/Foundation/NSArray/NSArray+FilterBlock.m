//
//  NSArray+FilterBlock.m
//  EX2Kit
//
//  Created by Benjamin Baron on 8/2/13.
//
//

#import "NSArray+FilterBlock.h"

@implementation NSArray (FilterBlock)

- (NSArray *)filteredArrayUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate
{
    NSIndexSet *filteredIndexes = [self indexesOfObjectsPassingTest:predicate];
    return [self objectsAtIndexes:filteredIndexes];
}

@end
