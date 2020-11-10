//
//  SUSServerPlaylistsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@class SUSServerPlaylistsLoader, FMDatabase;
@interface SUSServerPlaylistsDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property (weak) NSObject <ISMSLoaderDelegate> *delegate;
@property (strong) SUSServerPlaylistsLoader *loader;

#pragma mark - Public DAO Methods

@property (strong) NSArray *serverPlaylists;

@end
