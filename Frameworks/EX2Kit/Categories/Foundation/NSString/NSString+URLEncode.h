//
//  NSString+URLEncode.h
//  EX2Kit
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@interface NSString (URLEncode)

+ (NSString *)URLEncodeString:(NSString *)string; 
- (NSString *)URLEncodeString; 
- (NSString *)URLDecode;

@end
