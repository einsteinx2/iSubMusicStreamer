//
//  SUSQueueAllLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class ISMSFolderArtist, ISMSFolderAlbum, ISMSSong;
@interface SUSRecursiveSongLoader : SUSLoader

@property BOOL isQueue;
@property BOOL isShuffleButton;
@property BOOL doShowPlayer;
@property BOOL isCancelled;

@property (copy) NSString *currentPlaylist;
@property (copy) NSString *shufflePlaylist;

@property (strong) NSMutableArray<NSString*> *folderIds;

@property (strong) NSMutableArray<ISMSFolderAlbum*> *listOfFolderAlbums;
@property (strong) NSMutableArray<ISMSSong*> *listOfSongs;

- (void)loadData:(NSString *)folderId;

- (void)queueData:(NSString *)folderId;
- (void)cacheData:(NSString *)folderId;
- (void)playAllData:(NSString *)folderId;
- (void)shuffleData:(NSString *)folderId;

@end
