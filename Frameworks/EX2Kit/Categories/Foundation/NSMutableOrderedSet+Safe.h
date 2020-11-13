//
//  NSMutableOrderedSet+Safe.h
//  EX2Kit
//
//  Created by Benjamin Baron on 8/7/13.
//
//

#import <Foundation/Foundation.h>

@interface NSMutableOrderedSet (Safe)

- (void)addObjectSafe:(id)object;
- (void)insertObjectSafe:(id)object atIndex:(NSUInteger)index;
- (void)removeObjectAtIndexSafe:(NSUInteger)index;
- (void)removeObjectSafe:(id)object;
- (void)addObjectsFromArraySafe:(NSArray *)array;
+ (id)orderedSetWithArraySafe:(NSArray *)array;
- (id)initWithArraySafe:(NSArray *)array;

@end
