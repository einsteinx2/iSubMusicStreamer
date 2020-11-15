//
//  SearchXMLParser.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ISMSArtist, ISMSAlbum, ISMSSong;
@interface SearchXMLParser : NSObject <NSXMLParserDelegate>

@property (readonly) NSArray<ISMSArtist*> *listOfArtists;
@property (readonly) NSArray<ISMSAlbum*> *listOfAlbums;
@property (readonly) NSArray<ISMSSong*> *listOfSongs;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
