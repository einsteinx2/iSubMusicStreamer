//
//  SUSQueueAllLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSQueueAllLoader : SUSLoader

@property BOOL isQueue;
@property BOOL isShuffleButton;
@property BOOL doShowPlayer;
@property BOOL isCancelled;

@property (copy) NSString *currentPlaylist;
@property (copy) NSString *shufflePlaylist;

@property (strong) ISMSArtist *myArtist;

@property (strong) NSMutableArray *folderIds;

@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSMutableArray *listOfSongs;

- (void)loadData:(NSString *)folderId artist:(ISMSArtist *)theArtist;// isQueue:(BOOL)queue;

- (void)queueData:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)cacheData:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)playAllData:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)shuffleData:(NSString *)folderId artist:(ISMSArtist *)theArtist;

@end
