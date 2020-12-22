//
//  SUSQueueAllLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class ISMSFolderArtist, ISMSFolderAlbum, ISMSSong;
@interface SUSQueueAllLoader : SUSLoader

@property BOOL isQueue;
@property BOOL isShuffleButton;
@property BOOL doShowPlayer;
@property BOOL isCancelled;

@property (copy) NSString *currentPlaylist;
@property (copy) NSString *shufflePlaylist;

@property (strong) ISMSFolderArtist *folderArtist;

@property (strong) NSMutableArray<NSString*> *folderIds;

@property (strong) NSMutableArray<ISMSFolderAlbum*> *listOfFolderAlbums;
@property (strong) NSMutableArray<ISMSSong*> *listOfSongs;

- (void)loadData:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;

- (void)queueData:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)cacheData:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)playAllData:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)shuffleData:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;

@end
