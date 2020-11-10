//
//  ISMSError.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ISMSErrorDomain.h"

@interface NSError (ISMSError)

+ (NSString *)descriptionFromISMSCode:(NSUInteger)code;

+ (NSError *)errorWithISMSCode:(NSInteger)code;
+ (NSError *)errorWithISMSCode:(NSInteger)code extraAttributes:(NSDictionary *)attributes;
+ (NSError *)errorWithISMSCode:(NSInteger)code message:(NSString *)message;

@end
