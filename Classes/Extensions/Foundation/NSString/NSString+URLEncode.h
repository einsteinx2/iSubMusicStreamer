//
//  NSString+URLEncode.h
//  EX2Kit
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncode)

+ (NSString *)URLQueryEncodeString:(NSString *)string; 
- (NSString *)URLQueryEncodeString; 

@end
