//
//  NSString+URLEncode.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+URLEncode.h"

@implementation NSString (URLEncode)

+ (NSString *)URLQueryEncodeString:(NSString *)string  {
    return [string stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
} 

- (NSString *)URLQueryEncodeString {
    return [NSString URLQueryEncodeString:self]; 
}

@end
