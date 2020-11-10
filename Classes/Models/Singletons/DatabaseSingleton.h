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

@class FMDatabase, FMDatabaseQueue, ISMSArtist, ISMSAlbum, ISMSSong, SUSQueueAllLoader;

@interface DatabaseSingleton : NSObject 

@property (strong) NSString *databaseFolderPath;

@property (strong) FMDatabaseQueue *allAlbumsDbQueue;
@property (strong) FMDatabaseQueue *allSongsDbQueue;
@property (strong) FMDatabaseQueue *coverArtCacheDb540Queue;
@property (strong) FMDatabaseQueue *coverArtCacheDb320Queue;
@property (strong) FMDatabaseQueue *coverArtCacheDb60Queue;
@property (strong) FMDatabaseQueue *albumListCacheDbQueue;
@property (strong) FMDatabaseQueue *genresDbQueue;
@property (strong) FMDatabaseQueue *currentPlaylistDbQueue;
@property (strong) FMDatabaseQueue *localPlaylistsDbQueue;
@property (strong) FMDatabaseQueue *songCacheDbQueue;
@property (strong) FMDatabaseQueue *cacheQueueDbQueue;
@property (strong) FMDatabaseQueue *lyricsDbQueue;
@property (strong) FMDatabaseQueue *bookmarksDbQueue;
@property (strong) FMDatabaseQueue *metadataDbQueue;

@property (strong) SUSQueueAllLoader *queueAll;

+ (instancetype)sharedInstance;
+ (void) setAllSongsToBackup;
+ (void) setAllSongsToNotBackup;

- (void)setupDatabases;
- (void)setCurrentMetadataDatabase;
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

- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db;
- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum forId:(NSString *)folderId;
- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue;
- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db;

- (NSUInteger)serverPlaylistCount:(NSString *)md5;

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column;
- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column;

//- (void)queueSong:(ISMSSong *)aSong;
- (void)queueAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)downloadAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)playAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)shuffleAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist;
- (void)shufflePlaylist;

- (void)updateTableDefinitions;

@end

#endif
