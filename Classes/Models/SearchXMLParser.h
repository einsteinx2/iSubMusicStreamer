//
//  SearchXMLParser.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface SearchXMLParser : NSObject <NSXMLParserDelegate>

@property (strong) NSMutableArray *listOfArtists;
@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSMutableArray *listOfSongs;

- (SearchXMLParser *) initXMLParser;

@end
