//
//  SUSServerShuffleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSServerShuffleLoader.h"
#import "SearchXMLParser.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSServerShuffleLoader

- (void)startLoad
{
    // Start the 100 record open search to create shuffle list
	NSDictionary *parameters = nil;
	if (self.notification == nil)
	{
        parameters = [NSDictionary dictionaryWithObject:@"100" forKey:@"size"];
	}
	else
	{
		NSDictionary *userInfo = [self.notification userInfo];
		NSString *folderId = [NSString stringWithFormat:@"%i", [[userInfo objectForKey:@"folderId"] intValue]];
        //DLog(@"folderId: %@    %i", folderId, [[userInfo objectForKey:@"folderId"] intValue]);
		
		if ([folderId intValue] < 0)
            parameters = [NSDictionary dictionaryWithObject:@"100" forKey:@"size"];
		else
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"100", @"size", n2N(folderId), @"musicFolderId", nil];
	}
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getRandomSongs" parameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
	else
	{
        [self informDelegateLoadingFailed:nil];
		// Inform the user that the connection failed.

	}
}

- (void)processResponse
{
    // TODO: Refactor this with RaptureXML
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
    SearchXMLParser *parser = (SearchXMLParser*)[[SearchXMLParser alloc] initXMLParser];
    [xmlParser setDelegate:parser];
    [xmlParser parse];
    
    if (settingsS.isJukeboxEnabled)
    {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS jukeboxClearRemotePlaylist];
    }
    else
    {
        [databaseS resetCurrentPlaylistDb];
    }
    
    for(ISMSSong *aSong in parser.listOfSongs)
    {
        [aSong addToCurrentPlaylistDbQueue];
    }
    
    playlistS.isShuffle = NO;    
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    [self informDelegateLoadingFinished];
}

@end
