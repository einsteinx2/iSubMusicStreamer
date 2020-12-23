//
//  SUSTagAlbumDAO.h
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class FMDatabase, ISMSTagAlbum, ISMSSong, SUSTagAlbumLoader;

@interface SUSTagAlbumDAO: NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property NSUInteger songStartRow;
@property NSUInteger songsCount;

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (strong) SUSTagAlbumLoader *loader;

@property (copy) ISMSTagAlbum *tagAlbum;

@property (readonly) BOOL hasLoaded;

- (instancetype)initWithDelegate:(NSObject <SUSLoaderDelegate> *)delegate;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andTagAlbum:(ISMSTagAlbum *)tagAlbum;

- (ISMSSong *)songForTableViewRow:(NSUInteger)row;
- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row;

@end
