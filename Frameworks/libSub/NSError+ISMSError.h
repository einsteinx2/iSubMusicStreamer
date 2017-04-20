//
//  ISMSError.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@interface NSError (ISMSError)

- (id)initWithISMSCode:(NSInteger)code;
- (id)initWithISMSCode:(NSInteger)code withExtraAttributes:(NSDictionary *)attributes;
+ (NSError *)errorWithISMSCode:(NSInteger)code;
+ (NSError *)errorWithISMSCode:(NSInteger)code withExtraAttributes:(NSDictionary *)attributes;
+ (NSString *)descriptionFromISMSCode:(NSUInteger)code;

@end