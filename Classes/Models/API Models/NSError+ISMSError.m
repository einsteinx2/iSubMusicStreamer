//
//  ISMSError.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSError+ISMSError.h"

@implementation NSError (ISMSError)

+ (NSString *)descriptionFromISMSCode:(NSUInteger)code {
    switch (code) {
        case ISMSErrorCode_NotASubsonicServer: return ISMSErrorDesc_NotASubsonicServer;
        case ISMSErrorCode_NotXML: return ISMSErrorDesc_NotXML;
        case ISMSErrorCode_CouldNotCreateConnection: return ISMSErrorDesc_CouldNotCreateConnection;
        default: return nil;
    }
}

+ (NSError *)errorWithISMSCode:(NSInteger)code {
    NSString *description = [self descriptionFromISMSCode:code];
    return [NSError errorWithDomain:ISMSErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

+ (NSError *)errorWithISMSCode:(NSInteger)code extraAttributes:(NSDictionary *)attributes {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:attributes];
    dict[NSLocalizedDescriptionKey] = [self descriptionFromISMSCode:code];
    return [self errorWithDomain:ISMSErrorDomain code:code userInfo:dict];
}

+ (NSError *)errorWithISMSCode:(NSInteger)code message:(NSString *)message {
    return [self errorWithDomain:SUSErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
