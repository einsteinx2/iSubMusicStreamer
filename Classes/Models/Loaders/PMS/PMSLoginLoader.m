//
//  PMSLoginLoader.m
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSLoginLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation PMSLoginLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Login;
}

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate urlString:(NSString *)theUrlString username:(NSString *)theUsername password:(NSString *)thePassword
{
    if ((self = [super initWithDelegate:theDelegate]))
    {
        _urlString = theUrlString;
        _username = theUsername;
        _password = thePassword;
    }
    return self;
}

- (id)initWithCallbackBlock:(LoaderCallback)theBlock urlString:(NSString *)theUrlString username:(NSString *)theUsername password:(NSString *)thePassword
{
    if ((self = [super initWithCallbackBlock:theBlock]))
    {
        _urlString = theUrlString;
        _username = theUsername;
        _password = thePassword;
    }
    return self;
}


- (NSURLRequest *)createRequest
{
    if (self.urlString == nil || self.username == nil || self.password == nil)
        return nil;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:self.username, @"u", self.password, @"p", nil];
    return [NSMutableURLRequest requestWithPMSAction:@"login" urlString:self.urlString parameters:parameters byteOffset:0];
}

- (void)processResponse
{
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [[[SBJsonParser alloc] init] objectWithString:responseString];    
    
    self.sessionId = [response objectForKey:@"sessionId"];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}

@end
