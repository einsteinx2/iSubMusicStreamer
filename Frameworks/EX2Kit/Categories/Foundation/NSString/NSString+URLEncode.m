//
//  NSString+URLEncode.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+URLEncode.h"

@implementation NSString (URLEncode)

+ (NSString *)URLEncodeString:(NSString *)string 
{
    NSString *result = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                    (__bridge CFStringRef)string, NULL, CFSTR(";/?:@&=$+{}[]<>,"), kCFStringEncodingUTF8);
    
    
    return result;
} 

- (NSString *)URLEncodeString 
{ 
    return [NSString URLEncodeString:self]; 
}

- (NSString *)URLDecode
{
    return (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)self, CFSTR(""));
}

@end
