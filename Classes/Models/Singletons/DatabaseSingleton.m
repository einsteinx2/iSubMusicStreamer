//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "SUSQueueAllLoader.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

- (void)setupAllSongsDb {
	NSString *urlStringMd5 = [[settingsS urlString] md5];
	
	// Setup the allAlbums database
	NSString *path = [NSString stringWithFormat:@"%@/%@allAlbums.db", settingsS.databasePath, urlStringMd5];
	self.allAlbumsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the allSongs database
	path = [NSString stringWithFormat:@"%@/%@allSongs.db", settingsS.databasePath, urlStringMd5];
	self.allSongsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allSongsDbQueue inDatabase:^(FMDatabase *db)  {
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the Genres database
	path = [NSString stringWithFormat:@"%@/%@genres.db", settingsS.databasePath, urlStringMd5];
	self.genresDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.genresDbQueue inDatabase:^(FMDatabase *db) {
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
}

- (void)setupDatabases {
    DDLogVerbose(@"[DatabaseSingleton] Database path: %@", settingsS.databasePath);
    DDLogVerbose(@"[DatabaseSingleton] Updated database path: %@", settingsS.updatedDatabasePath);
    DDLogVerbose(@"[DatabaseSingleton] Database prefix: %@", settingsS.urlString.md5);
		
	// Only load Albums, Songs, and Genre databases if the user explicitly enabled them
	if (settingsS.isSongsTabEnabled) {
		[self setupAllSongsDb];
	}
    
    [self setupServerDatabase];
    [self setupSharedDatabase];
	
//    [self setupCoverArtDatabases];
//    [self setupPlaylistDatabases];
//    [self setupSongCacheDatabases];
//    [self setupLyricsDatabase];
//    [self setupBookmarksDatabase];
	
	[self updateTableDefinitions];
}

- (void)setupServerDatabase {
    
    //
    // Folder and album cache
    //
    
    NSString *path = [NSString stringWithFormat:@"%@/%@.db", settingsS.updatedDatabasePath, settingsS.urlString.sha1];
    self.serverDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.serverDbQueue inDatabase:^(FMDatabase *db)  {
        // TODO: Determine the best cache size, for now leave it at the default
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
        
        // Shared song table for other tables to join. This now allows all other tables that store songs to just store the song ID
        if (![db tableExists:@"song"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE song (%@, UNIQUE(songId))", ISMSSong.updatedStandardSongColumnSchema]];
        }
        
        //
        // Folder-based  browsing
        //
        
        // Cached albums table from folder-based browsing
        if (![db tableExists:@"folderAlbum"]) {
            [db executeUpdate:@"CREATE TABLE folderAlbum (folderId TEXT, subfolderId TEXT, itemOrder INTEGER, title TEXT, coverArtId TEXT, folderArtistId TEXT, folderArtistName TEXT, tagAlbumName TEXT, playCount INTEGER, year INTEGER)"];
            [db executeUpdate:@"CREATE INDEX folderAlbum__folderId_itemOrder ON folderAlbum (folderId, itemOrder)"];
        }
        
        // Cached song IDs table from folder-based browsing
        if (![db tableExists:@"folderSong"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE folderSong (folderId TEXT, itemOrder INTEGER, songId TEXT)"]];
            [db executeUpdate:@"CREATE INDEX folderSong__folderId_itemOrder ON folderSong (folderId, itemOrder)"];
        }
        
        // Cached "album" metadata from folder-based browsing
        if (![db tableExists:@"folderMetadata"]) {
            [db executeUpdate:@"CREATE TABLE folderMetadata (folderId TEXT PRIMARY KEY, subfolderCount INTEGER, songCount INTEGER, duration INTEGER)"];
        }
        
        //
        // Tag-based browsing
        //
        
        // Cached albums table from tag-based browsing
        if (![db tableExists:@"tagAlbum"]) {
            [db executeUpdate:@"CREATE TABLE tagAlbum (artistId TEXT, albumId TEXT, itemOrder INTEGER, name TEXT, coverArtId TEXT, tagArtistName TEXT, songCount INTEGER, duration INTEGER, playCount INTEGER, year INTEGER, genre TEXT)"];
            [db executeUpdate:@"CREATE INDEX tagAlbum__artistId_itemOrder ON tagAlbum (artistId, itemOrder)"];
        }
        
        // Cached Song IDs table from tag-based browsing
        if (![db tableExists:@"tagSong"]) {
            [db executeUpdate:@"CREATE TABLE tagSong (albumId TEXT, itemOrder INTEGER, songId TEXT)"];
            [db executeUpdate:@"CREATE INDEX tagSong__albumId_itemOrder ON tagSong (albumId, itemOrder)"];
        }
    }];
    
    //
    // Cover art cache
    //
    
    [self.serverDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if (![db tableExists:@"coverArtCacheSmall"]) {
            [db executeUpdate:@"CREATE TABLE coverArtCacheSmall (coverArtId TEXT PRIMARY KEY, data BLOB)"];
        }
        
        if (![db tableExists:@"coverArtCacheLarge"]) {
            [db executeUpdate:@"CREATE TABLE coverArtCacheLarge (coverArtId TEXT PRIMARY KEY, data BLOB)"];
        }
        
        if (![db tableExists:@"artistArtCache"]) {
            [db executeUpdate:@"CREATE TABLE artistArtCache (coverArtId TEXT PRIMARY KEY, data BLOB)"];
        }
    }];
    
    //
    // Playlists
    //
    
    [self.serverDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if (![db tableExists:@"currentPlaylist"])  {
            [db executeUpdate:@"CREATE TABLE currentPlaylist (songId TEXT, itemOrder INTEGER)"];
            [db executeUpdate:@"CREATE INDEX currentPlaylist__itemOrder ON currentPlaylist (itemOrder)"];
        }
        
        if (![db tableExists:@"shufflePlaylist"])  {
            [db executeUpdate:@"CREATE TABLE shufflePlaylist (songId TEXT, itemOrder INTEGER)"];
            [db executeUpdate:@"CREATE INDEX shufflePlaylist__itemOrder ON shufflePlaylist (itemOrder)"];
        }
        
        if (![db tableExists:@"jukeboxCurrentPlaylist"])  {
            [db executeUpdate:@"CREATE TABLE jukeboxCurrentPlaylist (songId TEXT, itemOrder INTEGER)"];
            [db executeUpdate:@"CREATE INDEX jukeboxCurrentPlaylist__itemOrder ON jukeboxCurrentPlaylist (itemOrder)"];
        }
        
        if (![db tableExists:@"jukeboxShufflePlaylist"])  {
            [db executeUpdate:@"CREATE TABLE jukeboxShufflePlaylist (songId TEXT, itemOrder INTEGER)"];
            [db executeUpdate:@"CREATE INDEX jukeboxShufflePlaylist__itemOrder ON jukeboxShufflePlaylist (itemOrder)"];
        }
        
        if (![db tableExists:@"localPlaylists"]) {
            [db executeUpdate:@"CREATE TABLE localPlaylists (playlistName TEXT, tableName TEXT, createdAt REAL, lastPlayed REAL)"];
        }
    }];
}

- (void)setupSharedDatabase {
    
}

//- (void)setupPlaylistDatabases {
//    // Setup the current playlist database
//    NSString *path;
//    if (settingsS.isOfflineMode) {
//        path = [NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", settingsS.databasePath];
//    } else {
//        path = [NSString stringWithFormat:@"%@/%@currentPlaylist.db", settingsS.databasePath, settingsS.urlString.md5];
//    }
//
//    self.currentPlaylistDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
//    [self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
//
//        if (![db tableExists:@"currentPlaylist"])  {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"currentPlaylist"]) {
//            BOOL success = [db executeUpdate:@"ALTER TABLE currentPlaylist ADD COLUMN discNumber INTEGER"];
//            DDLogInfo(@"[DatabaseSingleton] currentPlaylist has no discNumber and add worked: %d", success);
//        }
//
//        if (![db tableExists:@"shufflePlaylist"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"shufflePlaylist"])
//        {
//            BOOL success = [db executeUpdate:@"ALTER TABLE shufflePlaylist ADD COLUMN discNumber INTEGER"];
//            DDLogInfo(@"[DatabaseSingleton] shufflePlaylist has no discNumber and add worked: %d", success);
//        }
//
//        if (![db tableExists:@"jukeboxCurrentPlaylist"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"jukeboxCurrentPlaylist"]) {
//            BOOL success = [db executeUpdate:@"ALTER TABLE jukeboxCurrentPlaylist ADD COLUMN discNumber INTEGER"];
//            DDLogInfo(@"[DatabaseSingleton] jukeboxCurrentPlaylist has no discNumber and add worked: %d", success);
//        }
//
//        if (![db tableExists:@"jukeboxShufflePlaylist"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"jukeboxShufflePlaylist"]) {
//            BOOL success = [db executeUpdate:@"ALTER TABLE jukeboxShufflePlaylist ADD COLUMN discNumber INTEGER"];
//            DDLogInfo(@"[DatabaseSingleton] jukeboxShufflePlaylist has no discNumber and add worked: %d", success);
//        }
//    }];
//    [self setNoBackupFlagForDatabaseAtPath:path];
//
//    // Setup the local playlists database
//    if (settingsS.isOfflineMode) {
//        path = [NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", settingsS.databasePath];
//    } else {
//        path = [NSString stringWithFormat:@"%@/%@localPlaylists.db", settingsS.databasePath, settingsS.urlString.md5];
//    }
//
//    self.localPlaylistsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
//    [self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
//
//        if (![db tableExists:@"localPlaylists"]) {
//            [db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
//        }
//    }];
//    [self setNoBackupFlagForDatabaseAtPath:path];
//}

- (void)setupSongCacheDatabases {
    NSString *path = [settingsS.databasePath stringByAppendingPathComponent:@"songCache.db"];
    self.songCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"PRAGMA cache_size = 1"];
        
        if (![db tableExists:@"cachedSongs"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", ISMSSong.standardSongColumnSchema]];
            [db executeUpdate:@"CREATE INDEX cachedSongs_cachedDate ON cachedSongs (cachedDate DESC)"];
            [db executeUpdate:@"CREATE INDEX cachedSongs_playedDate ON cachedSongs (playedDate DESC)"];
        } else if(![db columnExists:@"discNumber" inTableWithName:@"cachedSongs"]) {
            DDLogInfo(@"[DatabaseSingleton] Added column discNumber on table cachedSongs");
            [db executeUpdate:@"ALTER TABLE cachedSongs ADD COLUMN discNumber INTEGER"];
        }
        
        [db executeUpdate:@"CREATE INDEX IF NOT EXISTS cachedSongs_md5 ON cachedSongs (md5)"];
        if (![db tableExists:@"cachedSongsLayout"]) {
            [db executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_genreLayout ON cachedSongsLayout (genre)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg1 ON cachedSongsLayout (seg1)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg2 ON cachedSongsLayout (seg2)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg3 ON cachedSongsLayout (seg3)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg4 ON cachedSongsLayout (seg4)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg5 ON cachedSongsLayout (seg5)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg6 ON cachedSongsLayout (seg6)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg7 ON cachedSongsLayout (seg7)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg8 ON cachedSongsLayout (seg8)"];
            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg9 ON cachedSongsLayout (seg9)"];
        }
        
        DDLogInfo(@"[DatabaseSingleton] checking if genres table exists");
        if (![db tableExists:@"genres"]) {
            DDLogInfo(@"[DatabaseSingleton] doesn't exist, creating genres table");
            [db executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
        }
        
        if (![db tableExists:@"genresSongs"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", ISMSSong.standardSongColumnSchema]];
            [db executeUpdate:@"CREATE INDEX genresSongs_genre ON genresSongs (genre)"];
        } else if(![db columnExists:@"discNumber" inTableWithName:@"genresSongs"]) {
            [db executeUpdate:@"ALTER TABLE genresSongs ADD COLUMN discNumber INTEGER"];
        }
        
        if (![db tableExists:@"sizesSongs"])
        {
            [db executeUpdate:@"CREATE TABLE sizesSongs(md5 TEXT UNIQUE, size INTEGER)"];
        }
    }];
    [self setNoBackupFlagForDatabaseAtPath:path];
    
    path = [settingsS.databasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@cacheQueue.db", settingsS.urlString.md5]];
    self.cacheQueueDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"PRAGMA cache_size = 1"];
        
        if (![db tableExists:@"cacheQueue"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", ISMSSong.standardSongColumnSchema]];
            //[cacheQueueDb executeUpdate:@"CREATE INDEX cacheQueue_queueDate ON cacheQueue (cachedDate DESC)"];
        } else if(![db columnExists:@"discNumber" inTableWithName:@"cacheQueue"]) {
            [db executeUpdate:@"ALTER TABLE cacheQueue ADD COLUMN discNumber INTEGER"];
        }
    }];
    [self setNoBackupFlagForDatabaseAtPath:path];
    
    if (!settingsS.isCacheSizeTableFinished) {
        // Do this in the background to prevent locking up the main thread for large caches
        [EX2Dispatch runInBackgroundAsync:^{
             NSMutableArray *cachedSongs = [NSMutableArray arrayWithCapacity:0];
             [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                 FMResultSet *result = [db executeQuery:@"SELECT * FROM cachedSongs WHERE finished = 'YES'"];
                 ISMSSong *song;
                 do {
                     song = [ISMSSong songFromDbResult:result];
                     if (song) {
                         [cachedSongs addObject:song];
                     }
                 }
                 while (song);
             }];
             
             for (ISMSSong *song in cachedSongs) {
                 @autoreleasepool {
                     NSString *filePath = [settingsS.songCachePath stringByAppendingPathComponent:song.path.md5];
                     NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                     if (attr) {
                         // Do this in individual blocks to prevent locking up the database which could also lock up the UI
                         [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
                              [db executeUpdate:@"INSERT OR IGNORE INTO sizesSongs VALUES(?, ?)", song.songId, attr[NSFileSize]];
                          }];
                         DDLogInfo(@"[DatabaseSingleton] Added %@ to the size table (%llu)", song.title, [attr fileSize]);
                     }
                 }
             }
             
             settingsS.isCacheSizeTableFinished = YES;
         }];
    }
}

- (void)setupLyricsDatabase {
    NSString *path = [NSString stringWithFormat:@"%@/lyrics.db", settingsS.databasePath];
    self.lyricsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.lyricsDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"PRAGMA cache_size = 1"];
        
        if (![db tableExists:@"lyrics"]) {
            [db executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
            [db executeUpdate:@"CREATE INDEX lyrics_artistTitle ON lyrics (artist, title)"];
        }
    }];
    [self setNoBackupFlagForDatabaseAtPath:path];
}

- (void)setupBookmarksDatabase {
    NSString *path;
    if (settingsS.isOfflineMode)  {
        path = [NSString stringWithFormat:@"%@/bookmarks.db", settingsS.databasePath];
    } else {
        path = [NSString stringWithFormat:@"%@/%@bookmarks.db", settingsS.databasePath, settingsS.urlString.md5];
    }
    
    self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"PRAGMA cache_size = 1"];
        
        if ([db tableExists:@"bookmarks"]) {
            // Make sure the isVideo column is there
            if (![db columnExists:@"isVideo" inTableWithName:@"bookmarks"]) {
                // Doesn't exist so fix the table definition
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
                [db executeUpdate:@"INSERT INTO bookmarksTemp SELECT bookmarkId, playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, 0, bytes FROM bookmarks"];
                [db executeUpdate:@"DROP TABLE bookmarks"];
                [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
                [db executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
            }
            
            if (![db columnExists:@"discNumber" inTableWithName:@"bookmarks"]) {
                [db executeUpdate:@"ALTER TABLE bookmarks ADD COLUMN discNumber INTEGER"];
            }
        } else {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
            [db executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
        }
    }];
    [self setNoBackupFlagForDatabaseAtPath:path];
}

- (void)setNoBackupFlagForDatabaseAtPath:(NSString *)path {
    // Set the no backup flag as per the user's settings
    NSURL *url = [NSURL fileURLWithPath:path];
    if (settingsS.isBackupCacheEnabled) {
        [url removeSkipBackupAttribute];
    } else {
        [url addSkipBackupAttribute];
    }
}

- (void)updateTableDefinitions {
	// Add conditional table update statements here as DB schema changes
    
    // TODO: Move song records from all playlist tables to the new database
    
    // TODO: Move data from old offline databases into offline prefixed tables in the shared db queue

    // TODO: Delete old database files
    
//    // Add parentId column to tables if necessary
//    NSArray *parentIdDatabaseQueues = @[self.albumListCacheDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.songCacheDbQueue, self.songCacheDbQueue, self.cacheQueueDbQueue];
//    NSArray *parentIdTables = @[@"songsCache", @"currentPlaylist", @"shufflePlaylist", @"jukeboxCurrentPlaylist", @"jukeboxShufflePlaylist", @"cachedSongs", @"genresSongs", @"cacheQueue"];
//    NSString *parentIdColumnName = @"parentId";
//    NSString *isVideoColumnName = @"isVideo";
//    for (int i = 0; i < [parentIdDatabaseQueues count]; i++)
//    {
//        FMDatabaseQueue *dbQueue = [parentIdDatabaseQueues objectAtIndexSafe:i];
//        NSString *table = [parentIdTables objectAtIndexSafe:i];
//
//        [dbQueue inDatabase:^(FMDatabase *db)
//        {
//            if (![db columnExists:parentIdColumnName inTableWithName:table])
//            {
//                NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
//                [db executeUpdate:query];
//            }
//
//            if (![db columnExists:isVideoColumnName inTableWithName:table])
//            {
//                NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
//                [db executeUpdate:query];
//            }
//        }];
//    }
//
//    // Add parentId to all playlist and splaylist tables
//    [self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
//    {
//        NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
//        NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
//        FMResultSet *result = [db executeQuery:query];
//        while ([result next])
//        {
//            @autoreleasepool
//            {
//                NSString *tableName = [result stringForColumnIndex:0];
//                if ([tableName length] > 8)
//                {
//                    NSString *tableNameSubstring = [tableName substringToIndex:8];
//                    if ([tableNameSubstring isEqualToString:@"playlist"] ||
//                        [tableNameSubstring isEqualToString:@"splaylis"])
//                    {
//                        [playlistTableNames addObject:tableName];
//                    }
//                }
//            }
//        }
//        [result close];
//
//        for (NSString *table in playlistTableNames)
//        {
//            if (![db columnExists:parentIdColumnName inTableWithName:table])
//            {
//                NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
//                [db executeUpdate:query];
//            }
//
//            if (![db columnExists:isVideoColumnName inTableWithName:table])
//            {
//                NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
//                [db executeUpdate:query];
//            }
//        }
//    }];
//
//    // Update the bookmarks table to new format
//    [self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
//    {
//        if (![db columnExists:@"bookmarkId" inTableWithName:@"bookmarks"])
//        {
//            // Create the new table
//            [db executeUpdate:@"DROP TABLE IF EXISTS bookmarksTemp"];
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
//
//            // Move the records
//            [db executeUpdate:@"INSERT INTO bookmarksTemp (playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) SELECT 0, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size FROM bookmarks"];
//
//            // Swap the tables
//            [db executeUpdate:@"DROP TABLE IF EXISTS bookmarks"];
//            [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
//            [db executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
//        }
//
//        if(![db columnExists:@"discNumber" inTableWithName:@"bookmarks"])
//        {
//            [db executeUpdate:@"ALTER TABLE bookmarks ADD COLUMN discNumber INTEGER"];
//        }
//    }];
//
//    [self.songCacheDbQueue inDatabase:^(FMDatabase *db)
//     {
//         if (![db tableExists:@"genresTableFixed"])
//         {
//             [db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
//             [db executeUpdate:@"CREATE TABLE genresTemp (genre TEXT)"];
//             [db executeUpdate:@"INSERT INTO genresTemp SELECT * FROM genres"];
//             [db executeUpdate:@"DROP TABLE genres"];
//             [db executeUpdate:@"ALTER TABLE genresTemp RENAME TO genres"];
//             [db executeUpdate:@"CREATE UNIQUE INDEX genreNames ON genres (genre)"];
//             [db executeUpdate:@"CREATE TABLE genresTableFixed (a INTEGER)"];
//         }
//     }];
}

- (void)closeAllDatabases {
    [self.serverDbQueue close]; self.serverDbQueue = nil;
    [self.sharedDbQueue close]; self.sharedDbQueue = nil;
    
	[self.allAlbumsDbQueue close]; self.allAlbumsDbQueue = nil;
	[self.allSongsDbQueue close]; self.allSongsDbQueue = nil;
	[self.genresDbQueue close]; self.genresDbQueue = nil;
	[self.currentPlaylistDbQueue close]; self.currentPlaylistDbQueue = nil;
	[self.localPlaylistsDbQueue close]; self.localPlaylistsDbQueue = nil;
	[self.songCacheDbQueue close]; self.songCacheDbQueue = nil;
	[self.cacheQueueDbQueue close]; self.cacheQueueDbQueue = nil;
	[self.bookmarksDbQueue close]; self.bookmarksDbQueue = nil;	
}

- (void)resetCoverArtCache {
	// Clear the table cell cover art	
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
		[db executeUpdate:@"DELETE FROM coverArtCacheSmall"];
        [db executeUpdate:@"DELETE FROM coverArtCacheLarge"];
        [db executeUpdate:@"DELETE FROM artistArtCache"];
        
        // Free up the disk space
        [db executeUpdate:@"VACUUM"];
	}];
}

- (void)resetFolderCache {
    [self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
        [db executeUpdate:@"DELETE FROM folderAlbum"];
        [db executeUpdate:@"DELETE FROM folderSong"];
        [db executeUpdate:@"DELETE FROM folderMetadata"];
        
        // Free up the disk space
        [db executeUpdate:@"VACUUM"];
    }];
}

- (void)resetAlbumCache {
    [self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
        [db executeUpdate:@"DELETE FROM tagAlbum"];
        [db executeUpdate:@"DELETE FROM tagSong"];
        
        // Free up the disk space
        [db executeUpdate:@"VACUUM"];
    }];
}

- (void)resetLocalPlaylistsDb {
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
		// Get the table names
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next]) {
			@autoreleasepool {
				NSString *tableName = [result stringForColumnIndex:0];
				[playlistTableNames addObject:tableName];
			}
		}
		[result close];
		
		// Drop the tables
		for (NSString *table in playlistTableNames) {
			NSString *query = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", table];
			[db executeUpdate:query];
		} 
		
		// Create the localPlaylists table
		[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}];
}

- (void)resetCurrentPlaylistDb {
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		// Drop the tables
		[db executeUpdate:@"DROP TABLE IF EXISTS currentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS shufflePlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxShufflePlaylist"];
		
		// Create the tables
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
	}];	
}

- (void)resetCurrentPlaylist {
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		if (settingsS.isJukeboxEnabled) {
			[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		} else {
			[db executeUpdate:@"DROP TABLE currentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		}
	}];
}

- (void)resetShufflePlaylist {
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		if (settingsS.isJukeboxEnabled) {
			[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		} else {
			[db executeUpdate:@"DROP TABLE shufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		}
	}];
}

- (void)resetJukeboxPlaylist {
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", ISMSSong.standardSongColumnSchema]];
		
		[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", ISMSSong.standardSongColumnSchema]];
	}];
}

- (void)createServerPlaylistTable:(NSString *)md5 {
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (%@)", md5, ISMSSong.standardSongColumnSchema]];
	}];	
}

- (void)removeServerPlaylistTable:(NSString *)md5 {
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
	}];
}

- (NSUInteger)serverPlaylistCount:(NSString *)md5 {
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [self.localPlaylistsDbQueue intForQuery:query];
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column {
	__block NSArray *sectionInfo;
	[dbQueue inDatabase:^(FMDatabase *db) {
		sectionInfo = [self sectionInfoFromTable:table inDatabase:db withColumn:column];
	}];
	return sectionInfo;
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column {
	NSArray *sectionTitles = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z"];
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
    for (int i = 0; i < sectionTitles.count; i++) {
        NSArray *articles = [NSString indefiniteArticles];
        NSString *section = [sectionTitles objectAtIndexSafe:i];
        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
        for (NSString *article in articles) {
            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
        }
        [query appendString:@"LIMIT 1"];

		NSString *row = [database stringForQuery:query];
		if (row != nil) {
			[sections addObject:@[[sectionTitles objectAtIndexSafe:i], @([row intValue] - 1)]];
		}
	}
	
	if (sections.count > 0) {
		if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0) {
			[sections insertObject:@[@"#", @0] atIndex:0];
		}
	} else {
		// Looks like there are only number rows, make sure the table is not empty
		NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ LIMIT 1", table]];
		if (row) {
			[sections insertObject:@[@"#", @0] atIndex:0];
		}
	}
	return sections;
}

- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column {
    __block NSArray *sectionInfo;
    [dbQueue inDatabase:^(FMDatabase *db) {
        sectionInfo = [self sectionInfoFromOrderColumnTable:table inDatabase:db withColumn:column];
    }];
    return sectionInfo;
}

- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column {
    NSArray *sectionTitles = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z"];
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < sectionTitles.count; i++) {
        NSArray *articles = [NSString indefiniteArticles];
        NSString *section = [sectionTitles objectAtIndexSafe:i];
        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT itemOrder FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
        for (NSString *article in articles) {
            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
        }
        [query appendString:@"LIMIT 1"];

        NSString *order = [database stringForQuery:query];
        if (order != nil) {
            [sections addObject:@[[sectionTitles objectAtIndexSafe:i], @(order.intValue)]];
        }
    }
    
    if (sections.count > 0) {
        if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0) {
            [sections insertObject:@[@"#", @0] atIndex:0];
        }
    } else {
        // Looks like there are only number rows, make sure the table is not empty
        NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT itemOrder FROM %@ LIMIT 1", table]];
        if (row) {
            [sections insertObject:@[@"#", @0] atIndex:0];
        }
    }
    return sections;
}

- (void)downloadAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist {
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Download all the songs
	[self.queueAll cacheData:folderId folderArtist:folderArtist];
}

- (void)queueAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist {
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Queue all the songs
	[self.queueAll queueData:folderId folderArtist:folderArtist];
}

- (void)playAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist {
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Set shuffle off in case it's on
	playlistS.isShuffle = NO;
	
	// Queue all the songs
	[self.queueAll playAllData:folderId folderArtist:folderArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId folderArtist:(ISMSFolderArtist *)folderArtist {
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}

	// Set shuffle on
	playlistS.isShuffle = YES;
	
	// Queue all the songs
	[self.queueAll shuffleData:folderId folderArtist:folderArtist];
}

- (void)shufflePlaylist {
	@autoreleasepool {
		playlistS.currentIndex = 0;
		playlistS.isShuffle = YES;
		
		[self resetShufflePlaylist];
		
		[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
            if (settingsS.isJukeboxEnabled) {
				[db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
            } else {
				[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
            }
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
}

#pragma mark - Singleton methods

- (void)setup  {
	_queueAll = [[SUSQueueAllLoader alloc] init];
	[self setupDatabases];
}

+ (void)setAllSongsToBackup {
    // Handle moving the song cache database if necessary
    NSString *path = [settingsS.databasePath stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if ([defaultManager fileExistsAtPath:path]) {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] removeSkipBackupAttribute];
    }
}

+ (void)setAllSongsToNotBackup {
    // Handle moving the song cache database if necessary
    NSString *path = [settingsS.databasePath stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if ([defaultManager fileExistsAtPath:path]) {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
    }
}

+ (instancetype)sharedInstance {
    static DatabaseSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
