//
//  SUSSubFolderLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

@class ISMSArtist, ISMSAlbum, ISMSSong, FMDatabaseQueue;
@interface ISMSSubFolderLoader : ISMSLoader

@property (nonatomic) NSUInteger albumsCount;
@property (nonatomic) NSUInteger songsCount;
@property (nonatomic) NSUInteger folderLength;

@property (copy) NSString *myId;
@property (copy) ISMSArtist *myArtist;

// Database methods
- (FMDatabaseQueue *)dbQueue;
- (ISMSLoaderType)type;
- (BOOL)resetDb;
- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum;
- (BOOL)insertSongIntoFolderCache:(ISMSSong *)aSong;
- (BOOL)insertAlbumsCount;
- (BOOL)insertSongsCount;
- (BOOL)insertFolderLength;


@end

#import "SUSSubFolderLoader.h"
#import "PMSSubFolderLoader.h"