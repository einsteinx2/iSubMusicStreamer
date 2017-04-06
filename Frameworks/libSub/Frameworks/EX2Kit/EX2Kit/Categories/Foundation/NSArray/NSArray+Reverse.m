//
//  NSArray+Reverse.m
//  EX2Kit
//
//  Created by Benjamin Baron on 7/8/13.
//
//

#import "NSArray+Reverse.h"

@implementation NSArray (Reverse)

- (NSArray *)reversedArray
{
    return [[self reverseObjectEnumerator] allObjects];
}

@end
