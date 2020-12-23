//
//  ISMSError.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ISMSErrorDomain.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSError (ISMSError)

+ (nullable NSString *)descriptionFromISMSCode:(NSUInteger)code;

+ (NSError *)errorWithISMSCode:(NSInteger)code;
+ (NSError *)errorWithISMSCode:(NSInteger)code extraAttributes:(NSDictionary *)attributes;
+ (NSError *)errorWithISMSCode:(NSInteger)code message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
