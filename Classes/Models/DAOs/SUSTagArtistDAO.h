//
//  SUSTagArtistDAO.h
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class FMDatabase, ISMSTagArtist, ISMSTagAlbum, ISMSSong, SUSTagArtistLoader;

@interface SUSTagArtistDAO: NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property NSUInteger albumStartRow;
@property NSUInteger albumsCount;

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (strong) SUSTagArtistLoader *loader;

@property (copy) ISMSTagArtist *tagArtist;

@property (readonly) BOOL hasLoaded;

- (instancetype)initWithDelegate:(NSObject <SUSLoaderDelegate> *)delegate;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andTagArtist:(ISMSTagArtist *)tagArtist;

- (ISMSTagAlbum *)tagAlbumForTableViewRow:(NSUInteger)row;

@end
