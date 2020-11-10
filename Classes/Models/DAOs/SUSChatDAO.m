//
//  SUSChatDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatDAO.h"
#import "SUSChatLoader.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSChatDAO

#pragma mark - Lifecycle

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		_delegate = theDelegate;
    }    
    return self;
}

- (void)dealloc
{
	[_loader cancelLoad];
	_loader.delegate = nil;
}

#pragma mark - Public DAO Methods

- (void)sendChatMessage:(NSString *)message
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(message) forKey:@"message"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"addChatMessage" parameters:parameters];

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:@"message"];
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotSendChatMessage withExtraAttributes:dict];
		[self.delegate loadingFailed:nil withError:error]; 
	}
}

#pragma mark - Connection delegate for sending messages

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
	[self.delegate loadingFailed:nil withError:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	self.receivedData = nil;
	self.connection = nil;
	
	[self startLoad];
}


#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[SUSChatLoader alloc] initWithDelegate:self];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	self.chatMessages = [NSArray arrayWithArray:self.loader.chatMessages];
	
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
