//
//  ISMSError.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSError+ISMSError.h"

@implementation NSError (ISMSError)

+ (NSString *)descriptionFromISMSCode:(NSUInteger)code
{
    NSString *description = nil;
    
    switch (code) 
    {
        case ISMSErrorCode_NotASubsonicServer:
            description = ISMSErrorDesc_NotASubsonicServer;
            break;
        case ISMSErrorCode_NotXML:
            description = ISMSErrorDesc_NotXML;
            break;
        case ISMSErrorCode_CouldNotCreateConnection:
            description = ISMSErrorDesc_CouldNotCreateConnection;
        default:
            break;
    }
    
    return description;
}

- (id)initWithISMSCode:(NSInteger)code
{
    NSString *description = [NSError descriptionFromISMSCode:code];
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    
    self = [self initWithDomain:ISMSErrorDomain code:code userInfo:dict];
    
    return self;
}

- (id)initWithISMSCode:(NSInteger)code withExtraAttributes:(NSDictionary *)attributes
{
    NSString *description = [NSError descriptionFromISMSCode:code];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    [dict addEntriesFromDictionary:attributes];
    
    self = [self initWithDomain:ISMSErrorDomain code:code userInfo:dict];
    
    return self;
}

+ (NSError *)errorWithISMSCode:(NSInteger)code
{
    return [[NSError alloc] initWithISMSCode:code];
}

+ (NSError *)errorWithISMSCode:(NSInteger)code withExtraAttributes:(NSDictionary *)attributes
{
    return [[NSError alloc] initWithISMSCode:code withExtraAttributes:attributes];
}

/*+ (NSError *)errorWithISMSCode:(NSInteger)code
{
    NSString *description = nil;
    
    switch (code) 
    {
        case ISMSErrorCode_NotASubsonicServer:
            description = ISMSErrorDesc_NotASubsonicServer;
            break;
        case ISMSErrorCode_NotXML:
            description = ISMSErrorDesc_NotXML;
            break;
        case ISMSErrorCode_CouldNotCreateConnection:
            description = ISMSErrorDesc_CouldNotCreateConnection;
        default:
            break;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:ISMSErrorDomain code:code userInfo:dict];
}

+ (NSError *)errorWithISMSCode:(NSInteger)code withExtraAttributes:(NSDictionary *)attributes
{
	NSError *error = [NSError errorWithISMSCode:code];
	
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[newDict addEntriesFromDictionary:[error userInfo]];
	[newDict addEntriesFromDictionary:attributes];
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithDictionary:newDict];
	NSError *newError = [NSError errorWithDomain:[error domain] code:[error code] userInfo:userInfo];
	
	return newError;
}*/

@end
