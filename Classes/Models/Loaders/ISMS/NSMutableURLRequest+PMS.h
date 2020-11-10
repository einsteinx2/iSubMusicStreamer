//
//  NSMutableURLRequest+PMS.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (PMS)

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action urlString:(NSString *)url parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action parameters:(NSDictionary *)parameters;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action itemId:(NSString *)itemId;
+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action;

@end
