//
//  NSMutableArray+Safe.h
//  EX2Kit
//
//  Created by Ben Baron on 6/11/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//


@interface NSMutableArray (Safe)

- (void)addObjectSafe:(id)object;
- (void)insertObjectSafe:(id)object atIndex:(NSUInteger)index;
- (void)removeObjectAtIndexSafe:(NSUInteger)index;
- (void)removeObjectSafe:(id)object;
- (void)addObjectsFromArraySafe:(NSArray *)array;
+ (id)arrayWithArraySafe:(NSArray *)array;
- (id)initWithArraySafe:(NSArray *)array;

@end
