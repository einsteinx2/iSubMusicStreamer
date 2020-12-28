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

@property BOOL isPartiallyCached;
@property BOOL isFullyCached;
@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;
@property (nullable, assign) NSDate *playedDate;

// Load song from database using song ID (eventually replace all initializers below with this one)
- (nullable instancetype)initWithSongId:(NSString *)songId;

+ (nullable ISMSSong *)songFromDbResult:(FMResultSet *)result;
+ (nullable ISMSSong *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
+ (nullable ISMSSong *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
+ (nullable ISMSSong *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
+ (nullable ISMSSong *)songFromGenreDb:(FMDatabase *)db md5:(NSString *)md5;
+ (nullable ISMSSong *)songFromGenreDbQueue:(NSString *)md5;
+ (nullable ISMSSong *)songFromCacheDb:(FMDatabase *)db md5:(NSString *)md5;
+ (nullable ISMSSong *)songFromCacheDbQueue:(NSString *)md5;
+ (nullable ISMSSong *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row;

- (BOOL)insertIntoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5;
- (BOOL)insertIntoGenreTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
- (BOOL)insertIntoGenreTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL)insertIntoCachedSongsTableDbQueue;

- (BOOL)addToCacheQueueDbQueue;
- (BOOL)removeFromCacheQueueDbQueue;

- (BOOL)addToCurrentPlaylistDbQueue;
- (BOOL)addToShufflePlaylistDbQueue;

- (BOOL)removeFromCachedSongsTableDbQueue;
+ (BOOL)removeSongFromCacheDbQueueByMD5:(NSString *)md5;

- (BOOL)insertIntoCachedSongsLayoutDbQueue;

- (BOOL)isCurrentPlayingSong;

// Read song from any table with an itemOrder column by joining against the shared song metadata table
+ (ISMSSong *)songAtPosition:(NSUInteger)itemOrder inTable:(NSString *)table;

// Read song from any table by joining against the shared song metadata table
+ (nullable ISMSSong *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table;

// Insert or update the shared song metadata
- (BOOL)updateMetadataCache;

+ (NSString *)standardSongColumnSchema;
+ (NSString *)standardSongColumnNames;
+ (NSString *)standardSongColumnQMarks;

+ (NSString *)updatedStandardSongColumnSchema;
+ (NSString *)updatedStandardSongColumnNames;
+ (NSString *)updatedStandardSongColumnQMarks;

@end

NS_ASSUME_NONNULL_END
