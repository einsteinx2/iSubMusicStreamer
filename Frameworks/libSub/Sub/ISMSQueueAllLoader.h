//
//  QueueAll.h
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//
#import "ISMSLoader.h"

@class ISMSArtist;

@interface ISMSQueueAllLoader : ISMSLoader 

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

- (void)finishLoad;

@end

#import "SUSQueueAllLoader.h"
#import "PMSQueueAllLoader.h"