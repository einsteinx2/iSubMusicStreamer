//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class FMDatabase, ISMSArtist, ISMSAlbum, ISMSSong, SUSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property NSUInteger albumStartRow;
@property NSUInteger songStartRow;
@property NSUInteger albumsCount;
@property NSUInteger songsCount;

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (strong) SUSSubFolderLoader *loader;

@property (copy) NSString *myId;
@property (copy) ISMSArtist *myArtist;

@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSUInteger folderLength;

- (NSArray *)sectionInfo;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate;
- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate andId:(NSString *)folderId andArtist:(ISMSArtist *)anArtist;

- (ISMSAlbum *)albumForTableViewRow:(NSUInteger)row;
- (ISMSSong *)songForTableViewRow:(NSUInteger)row;

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row;

@end
