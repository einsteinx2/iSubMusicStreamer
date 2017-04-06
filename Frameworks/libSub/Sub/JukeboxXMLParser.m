//
//  JukeboxXMLParser.m
//  iSub
//
//  Created by bbaron on 11/5/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "JukeboxXMLParser.h"
//#import "ServerListViewController.h"

@implementation JukeboxXMLParser

- (id)initXMLParser 
{	
	if ((self = [super init]))
	{
		_listOfSongs = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
#ifdef IOS
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
#endif
    
	if ([errorCode isEqualToString:@"50"])
	{
		settingsS.isJukeboxEnabled = NO;
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxDisabled];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
#ifdef IOS
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the Jukebox XML response." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
#endif
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if ([elementName isEqualToString:@"jukeboxPlaylist"])
	{
		self.currentIndex = [[attributeDict objectForKey:@"currentIndex"] intValue];
		self.isPlaying = [[attributeDict objectForKey:@"playing"] boolValue];
		self.gain = [[attributeDict objectForKey:@"gain"] floatValue];
		
		if (playlistS.isShuffle)
			[databaseS resetShufflePlaylist];
		else
			[databaseS resetJukeboxPlaylist];
	}
	else if ([elementName isEqualToString:@"entry"])
	{
		ISMSSong *aSong = [[ISMSSong alloc] initWithAttributeDict:attributeDict];
		if (aSong.path)
		{
			if (playlistS.isShuffle)
				[aSong insertIntoTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
			else
				[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
		}
	}
}

@end
