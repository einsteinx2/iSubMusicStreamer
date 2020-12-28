//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class FMDatabase, ISMSFolderArtist, ISMSFolderAlbum, ISMSFolderMetadata, ISMSSong, SUSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (readonly) NSUInteger albumsCount;
@property (readonly) NSUInteger songsCount;
@property (readonly) NSUInteger duration;

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (strong) SUSSubFolderLoader *loader;

@property (copy) ISMSFolderArtist *folderArtist;
@property (strong) ISMSFolderMetadata *folderMetadata;

@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;

- (NSArray *)sectionInfo;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andId:(NSString *)folderId andFolderArtist:(ISMSFolderArtist *)folderArtist;

- (ISMSFolderAlbum *)folderAlbumForTableViewRow:(NSUInteger)row;
- (ISMSSong *)songForTableViewRow:(NSUInteger)row;

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row;

@end
