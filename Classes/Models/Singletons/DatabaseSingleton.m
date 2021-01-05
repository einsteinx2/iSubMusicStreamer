//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "PlayQueueSingleton.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlayQueueSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

- (void)setupDatabases {
    DDLogVerbose(@"[DatabaseSingleton] Database path: %@", settingsS.databasePath);
    DDLogVerbose(@"[DatabaseSingleton] Updated database path: %@", settingsS.updatedDatabasePath);
    DDLogVerbose(@"[DatabaseSingleton] Database prefix: %@", settingsS.urlStringFilesystemSafe);
    
    [self setupServerDatabase];
    [self setupSharedDatabase];
    [self setupOfflineSongsDatabase];
	

	[self updateTableDefinitions];
}

- (void)setupServerDatabase {
    NSString *path = [[settingsS.updatedDatabasePath stringByAppendingPathComponent:settingsS.urlStringFilesystemSafe] stringByAppendingPathExtension:@"db"];
    self.serverDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    
    //
    // Folder and album cache
    //
    
    [self.serverDbQueue inDatabase:^(FMDatabase *db)  {
        // Shared song table for other tables to join. This now allows all other tables that store songs to just store the song ID
        if (![db tableExists:@"song"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE song (%@, UNIQUE(songId))", ISMSSong.standardSongColumnSchema]];
        }
        
        //
        // Folder-based  browsing
        //
        
        // Cached albums table from folder-based browsing
        if (![db tableExists:@"folderAlbum"]) {
            [db executeUpdate:@"CREATE TABLE folderAlbum (folderId TEXT, subfolderId TEXT, itemOrder INTEGER, title TEXT, coverArtId TEXT, tagArtistName TEXT, tagAlbumName TEXT, playCount INTEGER, year INTEGER)"];
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
        
        if (![db tableExists:@"localPlaylist"]) {
            [db executeUpdate:@"CREATE TABLE localPlaylist (playlistId INTEGER PRIMARY KEY, playlistName TEXT, createdAt REAL, lastPlayed REAL)"];
        }
    }];
    
    //
    // Offline Downloads
    //
    
    [self.serverDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if (![db tableExists:@"downloadQueue"]) {
            [db executeUpdate:@"CREATE TABLE downloadQueue (songId TEXT, itemOrder INTEGER)"];
            [db executeUpdate:@"CREATE INDEX downloadQueue__itemOrder ON downloadQueue (itemOrder)"];
        }
    }];
}

- (void)setupSharedDatabase {
    NSString *path = [settingsS.updatedDatabasePath stringByAppendingPathComponent:@"shared.db"];
    self.sharedDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    
    
    
    //
    // Lyrics
    //
    
    [self.sharedDbQueue inDatabase:^(FMDatabase *db) {
        if (![db tableExists:@"lyrics"]) {
            [db executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
            [db executeUpdate:@"CREATE INDEX lyrics__artist_title ON lyrics (artist, title)"];
        }
    }];
}

- (void)setupOfflineSongsDatabase {
    NSString *path = [settingsS.updatedDatabasePath stringByAppendingPathComponent:@"offlineSongs.db"];
    self.offlineSongsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self setNoBackupFlagForPath:path];
    
    //
    // Offline Songs
    //
    
    [self.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        // Shared song table for other tables to join. This now allows all other tables that store songs to just store the song ID
        if (![db tableExists:@"song"]) {
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE song (urlStringFilesystemSafe TEXT, %@, PRIMARY KEY(urlStringFilesystemSafe, songId))", ISMSSong.standardSongColumnSchema]];
        }
        
        // Main downloaded songs table with list of automatically and manually downloaded songs
        if (![db tableExists:@"offlineSong"]) {
            [db executeUpdate:@"CREATE TABLE offlineSong (urlStringFilesystemSafe TEXT, songId TEXT, finished INTEGER, pinned INTEGER, size INTEGER, cachedDate REAL, playedDate REAL, PRIMARY KEY(urlStringFilesystemSafe, songId))"];
        }
        
        // Lookup table to display cached songs as if we're browsing the folders
        if (![db tableExists:@"offlineSongFolderLayout"]) {
            [db executeUpdate:@"CREATE TABLE offlineSongFolderLayout (urlStringFilesystemSafe TEXT, songId TEXT, level INTEGER, pathComponent TEXT, PRIMARY KEY(urlStringFilesystemSafe, songId))"];
            [db executeUpdate:@"CREATE INDEX offlineSongFolderLayout__level_pathComponent ON offlineSongFolderLayout (level, pathComponent)"];
        }
        
//        // Metadata required to display songs by folder
//        // NOTE: Can't use LIKE queries because they're case-insensitive (can be turned off with a PRAGMA,
//        //       but that's database-wide and we don't want case sensitivity in other searches).
//        //
//        //       Also, FTS (full text search) can't be used because it's also case insensitive and is fuzzy
//        //       for better searching text. So trying to search `LIKE "/First path/Second path/%" to get exact
//        //       matches won't work reliably.
//        //
//        //       So there are only two options:
//        //       1. Load all song paths into memory and basically do "full table scan" searches in memory
//        //       2. Store the path split into individually indexed columns like this
//        //       3. Create a lookup table like (songId, segmentNumber, segmentValue) so that an unlimited number of
//        //
//        //       It feels really hacky, especially the hard limit on
//        if (![db tableExists:@"offlineSongFolderMetadata"]) {
//            [db executeUpdate:@"CREATE TABLE offlineSongFolderMetadata (urlStringFilesystemSafe TEXT, songId TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT, PRIMARY KEY(urlStringFilesystemSafe, songId))"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg1 ON offlineSongFolderMetadata (seg1)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg2 ON offlineSongFolderMetadata (seg2)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg3 ON offlineSongFolderMetadata (seg3)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg4 ON offlineSongFolderMetadata (seg4)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg5 ON offlineSongFolderMetadata (seg5)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg6 ON offlineSongFolderMetadata (seg6)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg7 ON offlineSongFolderMetadata (seg7)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg8 ON offlineSongFolderMetadata (seg8)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg9)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg10)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg11)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg12)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg13)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg14)"];
//            [db executeUpdate:@"CREATE INDEX offlineSongFolderMetadata__seg9 ON offlineSongFolderMetadata (seg15)"];
//        }
    }];
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
    [self setNoBackupFlagForPath:path];
}

- (void)setNoBackupFlagForPath:(NSString *)path {
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
}

- (void)closeAllDatabases {
    [self.serverDbQueue close]; self.serverDbQueue = nil;
    [self.sharedDbQueue close]; self.sharedDbQueue = nil;
    [self.offlineSongsDbQueue close]; self.offlineSongsDbQueue = nil;
    
	[self.allAlbumsDbQueue close]; self.allAlbumsDbQueue = nil;
	[self.allSongsDbQueue close]; self.allSongsDbQueue = nil;
	[self.genresDbQueue close]; self.genresDbQueue = nil;
	[self.currentPlaylistDbQueue close]; self.currentPlaylistDbQueue = nil;
	[self.localPlaylistsDbQueue close]; self.localPlaylistsDbQueue = nil;
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
        [db vacuum];
	}];
}

- (void)resetFolderCache {
    [self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
        [db executeUpdate:@"DELETE FROM folderAlbum"];
        [db executeUpdate:@"DELETE FROM folderSong"];
        [db executeUpdate:@"DELETE FROM folderMetadata"];
        
        // Free up the disk space
        [db vacuum];
    }];
}

- (void)resetAlbumCache {
    [self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
        [db executeUpdate:@"DELETE FROM tagAlbum"];
        [db executeUpdate:@"DELETE FROM tagSong"];
        
        // Free up the disk space
        [db vacuum];
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
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // Empty the tables
        // NOTE: Not running vacuum as this needs to be as fast as possible
		[db executeUpdate:@"DELETE FROM currentPlaylist"];
		[db executeUpdate:@"DELETE FROM shufflePlaylist"];
		[db executeUpdate:@"DELETE FROM jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DELETE FROM jukeboxShufflePlaylist"];
	}];	
}

- (void)resetCurrentPlaylist {
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // NOTE: Not running vacuum as this needs to be as fast as possible
        NSString *table = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@", table]];
	}];
}

- (void)resetShufflePlaylist {
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // NOTE: Not running vacuum as this needs to be as fast as possible
        NSString *table = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@", table]];
	}];
}

- (void)resetJukeboxPlaylist {
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
        // NOTE: Not running vacuum as this needs to be as fast as possible
		[db executeUpdate:@"DELETE FROM jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DELETE FROM jukeboxShufflePlaylist"];
	}];
}

- (void)createServerPlaylistTable:(NSInteger)playlistId {
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%ld (songId TEXT, itemOrder INTEGER)", playlistId]];
	}];	
}

- (void)removeServerPlaylistTable:(NSInteger)playlistId {
	[self.serverDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%ld", playlistId]];
	}];
}

- (NSUInteger)serverPlaylistCount:(NSInteger)playlistId {
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%ld", playlistId];
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

- (void)shufflePlaylist {
	@autoreleasepool {
		playQueueS.currentIndex = 0;
		playQueueS.isShuffle = YES;
		
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
