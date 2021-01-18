//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

- (void)setupDatabases {
    DDLogVerbose(@"[DatabaseSingleton] Database path: %@", settingsS.databasePath);
    DDLogVerbose(@"[DatabaseSingleton] Updated database path: %@", settingsS.updatedDatabasePath);
//    DDLogVerbose(@"[DatabaseSingleton] Database prefix: %@", settingsS.urlStringFilesystemSafe);
    
    [Store.shared setupDatabases];
}

- (void)setupSongCacheDatabases {
//    NSString *path = [NSString stringWithFormat:@"%@/shared.db", settingsS.updatedDatabasePath];
//    self.songCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
//    [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
//
//        if (![db tableExists:@"cachedSongs"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", ISMSSong.standardSongColumnSchema]];
//            [db executeUpdate:@"CREATE INDEX cachedSongs_cachedDate ON cachedSongs (cachedDate DESC)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongs_playedDate ON cachedSongs (playedDate DESC)"];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"cachedSongs"]) {
//            DDLogInfo(@"[DatabaseSingleton] Added column discNumber on table cachedSongs");
//            [db executeUpdate:@"ALTER TABLE cachedSongs ADD COLUMN discNumber INTEGER"];
//        }
//
//        [db executeUpdate:@"CREATE INDEX IF NOT EXISTS cachedSongs_md5 ON cachedSongs (md5)"];
//        if (![db tableExists:@"cachedSongsLayout"]) {
//            [db executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_genreLayout ON cachedSongsLayout (genre)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg1 ON cachedSongsLayout (seg1)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg2 ON cachedSongsLayout (seg2)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg3 ON cachedSongsLayout (seg3)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg4 ON cachedSongsLayout (seg4)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg5 ON cachedSongsLayout (seg5)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg6 ON cachedSongsLayout (seg6)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg7 ON cachedSongsLayout (seg7)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg8 ON cachedSongsLayout (seg8)"];
//            [db executeUpdate:@"CREATE INDEX cachedSongsLayout_seg9 ON cachedSongsLayout (seg9)"];
//        }
//
//        DDLogInfo(@"[DatabaseSingleton] checking if genres table exists");
//        if (![db tableExists:@"genres"]) {
//            DDLogInfo(@"[DatabaseSingleton] doesn't exist, creating genres table");
//            [db executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
//        }
//
//        if (![db tableExists:@"genresSongs"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", ISMSSong.standardSongColumnSchema]];
//            [db executeUpdate:@"CREATE INDEX genresSongs_genre ON genresSongs (genre)"];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"genresSongs"]) {
//            [db executeUpdate:@"ALTER TABLE genresSongs ADD COLUMN discNumber INTEGER"];
//        }
//
//        if (![db tableExists:@"sizesSongs"])
//        {
//            [db executeUpdate:@"CREATE TABLE sizesSongs(md5 TEXT UNIQUE, size INTEGER)"];
//        }
//    }];
//    [self setNoBackupFlagForDatabaseAtPath:path];
//
//    path = [settingsS.databasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@cacheQueue.db", settingsS.urlString.md5]];
//    self.cacheQueueDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
//    [self.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
//
//        if (![db tableExists:@"cacheQueue"]) {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", ISMSSong.standardSongColumnSchema]];
//            //[cacheQueueDb executeUpdate:@"CREATE INDEX cacheQueue_queueDate ON cacheQueue (cachedDate DESC)"];
//        } else if(![db columnExists:@"discNumber" inTableWithName:@"cacheQueue"]) {
//            [db executeUpdate:@"ALTER TABLE cacheQueue ADD COLUMN discNumber INTEGER"];
//        }
//    }];
//    [self setNoBackupFlagForDatabaseAtPath:path];
//
//    if (!settingsS.isCacheSizeTableFinished) {
//        // Do this in the background to prevent locking up the main thread for large caches
//        [EX2Dispatch runInBackgroundAsync:^{
//             NSMutableArray *cachedSongs = [NSMutableArray arrayWithCapacity:0];
//             [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//                 FMResultSet *result = [db executeQuery:@"SELECT * FROM cachedSongs WHERE finished = 'YES'"];
//                 ISMSSong *song;
//                 do {
//                     song = [ISMSSong songFromDbResult:result];
//                     if (song) {
//                         [cachedSongs addObject:song];
//                     }
//                 }
//                 while (song);
//             }];
//
//             for (ISMSSong *song in cachedSongs) {
//                 @autoreleasepool {
//                     NSString *filePath = [settingsS.songCachePath stringByAppendingPathComponent:song.path.md5];
//                     NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
//                     if (attr) {
//                         // Do this in individual blocks to prevent locking up the database which could also lock up the UI
//                         [self.songCacheDbQueue inDatabase:^(FMDatabase *db) {
//                              [db executeUpdate:@"INSERT OR IGNORE INTO sizesSongs VALUES(?, ?)", song.songId, attr[NSFileSize]];
//                          }];
//                         DDLogInfo(@"[DatabaseSingleton] Added %@ to the size table (%llu)", song.title, [attr fileSize]);
//                     }
//                 }
//             }
//
//             settingsS.isCacheSizeTableFinished = YES;
//         }];
//    }
}

- (void)setupBookmarksDatabase {
//    NSString *path;
//    if (settingsS.isOfflineMode)  {
//        path = [NSString stringWithFormat:@"%@/bookmarks.db", settingsS.databasePath];
//    } else {
//        path = [NSString stringWithFormat:@"%@/%@bookmarks.db", settingsS.databasePath, settingsS.urlString.md5];
//    }
//    
//    self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
//    [self.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
//        [db executeUpdate:@"PRAGMA cache_size = 1"];
//        
//        if ([db tableExists:@"bookmarks"]) {
//            // Make sure the isVideo column is there
//            if (![db columnExists:@"isVideo" inTableWithName:@"bookmarks"]) {
//                // Doesn't exist so fix the table definition
//                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
//                [db executeUpdate:@"INSERT INTO bookmarksTemp SELECT bookmarkId, playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, 0, bytes FROM bookmarks"];
//                [db executeUpdate:@"DROP TABLE bookmarks"];
//                [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
//                [db executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
//            }
//            
//            if (![db columnExists:@"discNumber" inTableWithName:@"bookmarks"]) {
//                [db executeUpdate:@"ALTER TABLE bookmarks ADD COLUMN discNumber INTEGER"];
//            }
//        } else {
//            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", ISMSSong.standardSongColumnSchema]];
//            [db executeUpdate:@"CREATE INDEX bookmarks_songId ON bookmarks (songId)"];
//        }
//    }];
//    [self setNoBackupFlagForDatabaseAtPath:path];
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

- (void)closeAllDatabases {
    [Store.shared closeAllDatabases];
}

//- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column {
//	__block NSArray *sectionInfo;
//	[dbQueue inDatabase:^(FMDatabase *db) {
//		sectionInfo = [self sectionInfoFromTable:table inDatabase:db withColumn:column];
//	}];
//	return sectionInfo;
//}
//
//- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column {
//	NSArray *sectionTitles = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z"];
//	NSMutableArray *sections = [[NSMutableArray alloc] init];
//	
//    for (int i = 0; i < sectionTitles.count; i++) {
//        NSArray *articles = [NSString indefiniteArticles];
//        NSString *section = [sectionTitles objectAtIndexSafe:i];
//        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
//        for (NSString *article in articles) {
//            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
//        }
//        [query appendString:@"LIMIT 1"];
//
//		NSString *row = [database stringForQuery:query];
//		if (row != nil) {
//			[sections addObject:@[[sectionTitles objectAtIndexSafe:i], @([row intValue] - 1)]];
//		}
//	}
//	
//	if (sections.count > 0) {
//		if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0) {
//			[sections insertObject:@[@"#", @0] atIndex:0];
//		}
//	} else {
//		// Looks like there are only number rows, make sure the table is not empty
//		NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ LIMIT 1", table]];
//		if (row) {
//			[sections insertObject:@[@"#", @0] atIndex:0];
//		}
//	}
//	return sections;
//}
//
//- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column {
//    __block NSArray *sectionInfo;
//    [dbQueue inDatabase:^(FMDatabase *db) {
//        sectionInfo = [self sectionInfoFromOrderColumnTable:table inDatabase:db withColumn:column];
//    }];
//    return sectionInfo;
//}
//
//- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column {
//    NSArray *sectionTitles = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z"];
//    NSMutableArray *sections = [[NSMutableArray alloc] init];
//    
//    for (int i = 0; i < sectionTitles.count; i++) {
//        NSArray *articles = [NSString indefiniteArticles];
//        NSString *section = [sectionTitles objectAtIndexSafe:i];
//        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT itemOrder FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
//        for (NSString *article in articles) {
//            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
//        }
//        [query appendString:@"LIMIT 1"];
//
//        NSString *order = [database stringForQuery:query];
//        if (order != nil) {
//            [sections addObject:@[[sectionTitles objectAtIndexSafe:i], @(order.intValue)]];
//        }
//    }
//    
//    if (sections.count > 0) {
//        if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0) {
//            [sections insertObject:@[@"#", @0] atIndex:0];
//        }
//    } else {
//        // Looks like there are only number rows, make sure the table is not empty
//        NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT itemOrder FROM %@ LIMIT 1", table]];
//        if (row) {
//            [sections insertObject:@[@"#", @0] atIndex:0];
//        }
//    }
//    return sections;
//}

#pragma mark - Singleton methods

- (void)setup  {
	[self setupDatabases];
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
