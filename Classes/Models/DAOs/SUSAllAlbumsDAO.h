//
//  SUSAllAlbumsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabase, ISMSAlbum;

@interface SUSAllAlbumsDAO : NSObject
{
	__strong NSArray *index;
}

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) BOOL isDataLoaded;

- (NSArray *)index;

- (ISMSAlbum *)albumForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForAlbumName:(NSString *)name;
- (ISMSAlbum *)albumForPositionInSearch:(NSUInteger)position;

@end
