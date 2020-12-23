//
//  DatabaseSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_DatabaseSingleton_h
#define iSub_DatabaseSingleton_h

#import <Foundation/Foundation.h>

#define databaseS ((DatabaseSingleton *)[DatabaseSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

@class FMDatabase, FMDatabaseQueue, ISMSFolderArtist, ISMSSong, SUSQueueAllLoader;

NS_SWIFT_NAME(Database)
@interface DatabaseSingleton : NSObject 

@property (strong) NSString *databaseFolderPath;

@property (nullable, strong) FMDatabaseQueue *allAlbumsDbQueue;
@property (nullable, strong) FMDatabaseQueue *allSongsDbQueue;
@property (nullable, strong) FMDatabaseQueue *coverArtCacheDb540Queue;
@property (nullable, strong) FMDatabaseQueue *coverArtCacheDb320Queue;
@property (nullable, strong) FMDatabaseQueue *coverArtCacheDb60Queue;
@property (nullable, strong) FMDatabaseQueue *albumListCacheDbQueue;
@property (nullable, strong) FMDatabaseQueue *genresDbQueue;
@property (nullable, strong) FMDatabaseQueue *currentPlaylistDbQueue;
@property (nullable, strong) FMDatabaseQueue *localPlaylistsDbQueue;
@property (nullable, strong) FMDatabaseQueue *songCacheDbQueue;
@property (nullable, strong) FMDatabaseQueue *cacheQueueDbQueue;
@property (nullable, strong) FMDatabaseQueue *lyricsDbQueue;
@property (nullable, strong) FMDatabaseQueue *bookmarksDbQueue;

@property (strong) SUSQueueAllLoader *queueAll;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());
+ (void)setAllSongsToBackup;
+ (void)setAllSongsToNotBackup;

- (void)setupDatabases;
- (void)closeAllDatabases;
- (void)resetCoverArtCache;
- (void)resetFolderCache;
- (void)resetLocalPlaylistsDb;
- (void)resetCurrentPlaylistDb;
- (void)resetCurrentPlaylist;
- (void)resetShufflePlaylist;
- (void)resetJukeboxPlaylist;

- (void)setupAllSongsDb;

- (void)createServerPlaylistTable:(NSString *)md5;
- (void)removeServerPlaylistTable:(NSString *)md5;

- (NSUInteger)serverPlaylistCount:(NSString *)md5;

- (nullable NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column;
- (nullable NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column;

- (void)queueAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)downloadAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)playAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)shuffleAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist;
- (void)shufflePlaylist;

- (void)updateTableDefinitions;

@end

NS_ASSUME_NONNULL_END

#endif
