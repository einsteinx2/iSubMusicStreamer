//
//  SUSAllAlbumsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabase, ISMSFolderAlbum;

@interface SUSAllAlbumsDAO : NSObject {
	__strong NSArray *index;
}

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) BOOL isDataLoaded;

- (NSArray *)index;

- (ISMSFolderAlbum *)folderAlbumForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForAlbumName:(NSString *)name;
- (ISMSFolderAlbum *)folderAlbumForPositionInSearch:(NSUInteger)position;

@end
