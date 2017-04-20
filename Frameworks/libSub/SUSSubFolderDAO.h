//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@class FMDatabase, ISMSArtist, ISMSAlbum, ISMSSong, ISMSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property NSUInteger albumStartRow;
@property NSUInteger songStartRow;
@property NSUInteger albumsCount;
@property NSUInteger songsCount;

@property (weak) id<ISMSLoaderDelegate> delegate;
@property (strong) ISMSSubFolderLoader *loader;

@property (copy) NSString *myId;
@property (copy) ISMSArtist *myArtist;

@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSUInteger folderLength;

- (NSArray *)sectionInfo;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;
- (id)initWithDelegate:(id<ISMSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(ISMSArtist *)anArtist;

- (ISMSAlbum *)albumForTableViewRow:(NSUInteger)row;
- (ISMSSong *)songForTableViewRow:(NSUInteger)row;

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row;

@end
