//
//  NSMutableURLRequest+SUS.h
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (SUS)

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters;
+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters;

@end
