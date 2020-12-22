//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class FMDatabase, ISMSFolderArtist, ISMSFolderAlbum, ISMSSong, SUSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property NSUInteger albumStartRow;
@property NSUInteger songStartRow;
@property NSUInteger albumsCount;
@property NSUInteger songsCount;

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (strong) SUSSubFolderLoader *loader;

@property (copy) NSString *folderId;
@property (copy) ISMSFolderArtist *folderArtist;

@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSUInteger folderLength;

- (NSArray *)sectionInfo;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate;
- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andId:(NSString *)folderId andFolderArtist:(ISMSFolderArtist *)folderArtist;

- (ISMSFolderAlbum *)folderAlbumForTableViewRow:(NSUInteger)row;
- (ISMSSong *)songForTableViewRow:(NSUInteger)row;

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row;

@end
