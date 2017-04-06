//
//  NSOrderedSet+Safe.h
//  EX2Kit
//
//  Created by Benjamin Baron on 8/7/13.
//
//

#import <Foundation/Foundation.h>

@interface NSOrderedSet (Safe)

- (id)objectAtIndexSafe:(NSUInteger)index;
+ (id)orderedSetWithArraySafe:(NSArray *)array;
- (id)initWithArraySafe:(NSArray *)array;

@end
