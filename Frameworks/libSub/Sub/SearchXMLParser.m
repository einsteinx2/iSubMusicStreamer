//
//  SearchXMLParser.m
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchXMLParser.h"

@implementation SearchXMLParser

- (id)initXMLParser 
{	
	if ((self = [super init]))
	{
		_listOfArtists = [[NSMutableArray alloc] init];
		_listOfAlbums = [[NSMutableArray alloc] init];
		_listOfSongs = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    // TODO: uncomment this
	/*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Subsonic may have had an error performing the search." delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];*/
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if ([elementName isEqualToString:@"match"] || [elementName isEqualToString:@"song"])
	{
		if (![[attributeDict objectForKey:@"isVideo"] isEqualToString:@"true"])
		{
			ISMSSong *aSong = [[ISMSSong alloc] initWithAttributeDict:attributeDict];
		
			if (aSong.path)
			{
				[self.listOfSongs addObject:aSong];
			}
		
		}
	}
	else if ([elementName isEqualToString:@"album"])
	{
		ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithAttributeDict:attributeDict];
		
		[self.listOfAlbums addObject:anAlbum];
		
	}
	else if ([elementName isEqualToString:@"artist"])
	{
		ISMSArtist *anArtist = [[ISMSArtist alloc] initWithAttributeDict:attributeDict];
		
		[self.listOfArtists addObject:anArtist];
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{ 

}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	
	
}

@end
