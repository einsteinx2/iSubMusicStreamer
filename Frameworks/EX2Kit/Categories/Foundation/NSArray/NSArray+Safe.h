//
//  NSArray+Safe.h
//  EX2Kit
//
//  Created by Ben Baron on 2/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (Safe)

- (id)objectAtIndexSafe:(NSUInteger)index;
+ (id)arrayWithArraySafe:(NSArray *)array;
- (id)initWithArraySafe:(NSArray *)array;

@end
