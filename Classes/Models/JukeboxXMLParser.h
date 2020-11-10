//
//  JukeboxXMLParser.h
//  iSub
//
//  Created by bbaron on 11/5/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface JukeboxXMLParser : NSObject <NSXMLParserDelegate>

@property NSUInteger currentIndex;
@property BOOL isPlaying;
@property float gain;

@property (strong) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end