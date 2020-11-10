//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"
#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@interface ISMSLoader ()
@property (nonatomic, strong) ISMSLoader *selfRef;
@end

@implementation ISMSLoader

+ (id)loader
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	
	return nil;
}

+ (id)loaderWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	[NSException raise:NSInternalInconsistencyException
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	
	return nil;
}

- (void)setup
{
    
}

- (id)init
{
    self = [super init];
    if (self) 
	{
        [self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		_delegate = theDelegate;
	}
	
	return self;
}

- (id)initWithCallbackBlock:(LoaderCallback)theBlock
{
	self = [super init];
    if (self)
	{
        [self setup];
		_callbackBlock = [theBlock copy];
	}
	
	return self;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Generic;
}

- (void)startLoad
{
    self.request = [self createRequest];
    if (self.request)
    {
        self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
        if (self.connection)
        {
            // Create the NSMutableData to hold the received data.
            // receivedData is an instance variable declared elsewhere.
            self.receivedData = [NSMutableData data];
            
            if (!self.selfRef)
                self.selfRef = self;
        }
        else
        {
            // Inform the delegate that the loading failed.
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
            [self informDelegateLoadingFailed:error];
        }
    }
    else
    {
        // Inform the delegate that the loading failed.
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
    }
}

- (void)cancelLoad
{
	// Clean up connection objects
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
    
    self.selfRef = nil;
}

- (NSURLRequest *)createRequest
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	return nil;
}

- (void)processResponse
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message
{	
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self informDelegateLoadingFailed:error];
}

- (void)informDelegateLoadingFailed:(NSError *)error
{
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:self withError:error];
	}
    
    if (self.callbackBlock)
    {
        self.callbackBlock(NO, error, self);
    }
        
    self.selfRef = nil;
}

- (void)informDelegateLoadingFinished
{
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:self];
        
	}
    
    if (self.callbackBlock)
    {
        self.callbackBlock(YES, nil, self);
    }
	
	self.selfRef = nil;
}

#pragma mark Connection Delegate

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse)
    {
        // Notify the delegate
        if ([self.delegate respondsToSelector:@selector(loadingRedirected:redirectUrl:)])
        {
			[self.delegate loadingRedirected:self redirectUrl:inRequest.URL];
        }
        
        NSMutableURLRequest *r = [self.request mutableCopy]; // original request
		[r setTimeoutInterval:ISMSServerCheckTimeout];
        [r setURL:[inRequest URL]];
        return r;
    }
    else
    {
        //DLog(@"returning inRequest");
        return inRequest;
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.response = response;
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
    DLog(@"loader type: %i response:\n%@", self.type, [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	[self processResponse];
	
	// Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
