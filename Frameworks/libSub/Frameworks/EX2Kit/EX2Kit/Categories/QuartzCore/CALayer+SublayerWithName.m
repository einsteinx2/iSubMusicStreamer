//
//  CALayer+SublayerWithName.m
//  EX2Kit
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "CALayer+SublayerWithName.h"

@implementation CALayer (SublayerWithName)

- (CALayer *)sublayerWithName:(NSString *)name
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == '%@'", name];
	NSArray *filteredArray = [self.sublayers filteredArrayUsingPredicate:predicate];
	return filteredArray.count > 0 ? [filteredArray objectAtIndex:0] : nil;
}

@end
