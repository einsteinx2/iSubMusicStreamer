//
//  NSOrderedSet+FilterBlock.h
//  EX2Kit
//
//  Created by Benjamin Baron on 9/6/13.
//
//

#import <Foundation/Foundation.h>

@interface NSOrderedSet (FilterBlock)

- (NSOrderedSet *)filteredOrderedSetUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate;

@end
