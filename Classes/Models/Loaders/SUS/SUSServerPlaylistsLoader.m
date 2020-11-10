//
//  SUSServerPlaylistLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylistsLoader.h"
#import "SUSServerPlaylist.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSServerPlaylistsLoader

#pragma mark - Lifecycle

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.localPlaylistsDbQueue;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_ServerPlaylist;
}

#pragma mark - Private DB Methods

#pragma mark - Loader Methods

- (void)startLoad
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylists" parameters:nil];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
        self.serverPlaylists = nil;
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

#pragma mark - Connection Delegate

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
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
        }
        else
        {
            NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:0];
            [root iterate:@"playlists.playlist" usingBlock:^(RXMLElement *e) {
                SUSServerPlaylist *serverPlaylist = [[SUSServerPlaylist alloc] initWithRXMLElement:e];
                [tempArray addObject:serverPlaylist];
            }];
        
            // Sort the array
            self.serverPlaylists = [tempArray sortedArrayUsingSelector:@selector(compare:)];
			            
            // Notify the delegate that the loading is finished
			[self informDelegateLoadingFinished];
		}
	}
}

@end
