//
//  NSArray+FilterBlock.h
//  EX2Kit
//
//  Created by Benjamin Baron on 8/2/13.
//
// https://github.com/Gabro/NSArray-filter-using-block

#import <Foundation/Foundation.h>

@interface NSArray (FilterBlock)

- (NSArray *)filteredArrayUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate;

@end
