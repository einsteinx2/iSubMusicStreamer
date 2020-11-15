//
//  SearchXMLParser.m
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchXMLParser.h"
#import "iSubAppDelegate.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSSong+DAO.h"

@interface SearchXMLParser() {
    __strong NSMutableArray<ISMSArtist*> *_listOfArtists;
    __strong NSMutableArray<ISMSAlbum*> *_listOfAlbums;
    __strong NSMutableArray<ISMSSong*> *_listOfSongs;
}
@end

@implementation SearchXMLParser

- (NSArray<ISMSArtist*> *)listOfArtists { return _listOfArtists; }
- (NSArray<ISMSAlbum*> *)listOfAlbums { return _listOfAlbums; }
- (NSArray<ISMSSong*> *)listOfSongs { return _listOfSongs; }

- (instancetype)init  {
	if (self = [super init]) {
		_listOfArtists = [[NSMutableArray alloc] init];
		_listOfAlbums = [[NSMutableArray alloc] init];
		_listOfSongs = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // TODO: uncomment this
	/*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:@"There was an error parsing the XML response. Subsonic may have had an error performing the search." delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	alert.tag = 1;
	[alert show];*/
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	if ([elementName isEqualToString:@"match"] || [elementName isEqualToString:@"song"]) {
		if (![[attributeDict objectForKey:@"isVideo"] isEqualToString:@"true"]) {
			ISMSSong *song = [[ISMSSong alloc] initWithAttributeDict:attributeDict];
			if (song.path) {
				[_listOfSongs addObject:song];
            }
		}
	} else if ([elementName isEqualToString:@"album"]) {
		[_listOfAlbums addObject:[[ISMSAlbum alloc] initWithAttributeDict:attributeDict]];
	} else if ([elementName isEqualToString:@"artist"]) {
		[_listOfArtists addObject:[[ISMSArtist alloc] initWithAttributeDict:attributeDict]];
	}
}

@end
