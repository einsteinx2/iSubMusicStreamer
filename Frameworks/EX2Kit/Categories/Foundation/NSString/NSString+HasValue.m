//
//  NSString+HasValue.m
//  Anghami
//
//  Created by Benjamin Baron on 9/25/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSString+HasValue.h"

@implementation NSString (HasValue)

// This can be used to check to verify that a string is either nil or blank
// since if the string is nil, calling this will automatically return NO
- (BOOL)hasValue
{
    return ![self isEqualToString:@""];
}

@end
