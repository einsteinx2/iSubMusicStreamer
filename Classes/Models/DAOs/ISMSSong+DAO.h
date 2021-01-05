//
//  Song+DAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ISMSSong.h"

NS_ASSUME_NONNULL_BEGIN

@class FMDatabase, FMDatabaseQueue, FMResultSet;
@interface ISMSSong (DAO)

#pragma mark Properties

@property BOOL isFullyCached;
@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;
@property (nullable, assign) NSDate *playedDate;
@property (readonly) BOOL isCurrentPlayingSong;

#pragma mark Retrieve

- (nullable instancetype)initWithSongId:(NSString *)songId;

+ (ISMSSong *)songAtPosition:(NSUInteger)itemOrder inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
+ (ISMSSong *)songAtPositionInCurrentPlayQueue:(NSUInteger)itemOrder;
+ (ISMSSong *)songAtPosition:(NSUInteger)itemOrder fromServerPlaylistId:(NSUInteger)playlistId;
+ (ISMSSong *)downloadedSongWithUrlStringFilesystemSafe:(NSString *)urlStringFilesystemSafe songId:(NSString *)songId;
+ (ISMSSong *)songAtPositionInDownloadQueue:(NSUInteger)itemOrder;

#pragma mark Store and Delete

- (BOOL)addToOfflineSongs;
- (BOOL)addToOfflineSongFolderLayout;
- (BOOL)removeFromOfflineSongs;
+ (BOOL)removeFromOfflineSongsWithUrlStringFilesystemSafe:(NSString *)urlStringFilesystemSafe songId:(NSString *)songId;

- (BOOL)addToDownloadQueue;
- (BOOL)removeFromDownloadQueue;

- (BOOL)addToCurrentPlayQueue;
- (BOOL)addToShufflePlayQueue;

- (BOOL)isCurrentPlayingSong;

// Insert or update the shared song metadata
- (BOOL)updateMetadataCache;
- (BOOL)updateOfflineMetadataCache;

// Query helpers
+ (NSString *)standardSongColumnSchema;
+ (NSString *)standardSongColumnNames;
+ (NSString *)standardSongColumnQMarks;

@end

NS_ASSUME_NONNULL_END
