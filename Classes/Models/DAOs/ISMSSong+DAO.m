//
//  Song+DAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSSong+DAO.h"
#import "FMDatabaseQueueAdditions.h"
#import "PlayQueueSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSStreamManager.h"
#import "BassGaplessPlayer.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlayQueueSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "EX2Kit.h"

LOG_LEVEL_ISUB_DEFAULT

// TODO: Add any missing error handling to all database accesses
@implementation ISMSSong (DAO)

#pragma mark Properties

- (BOOL)isFullyCached {
    return [databaseS.offlineSongsDbQueue boolForQuery:@"SELECT finished FROM offlineSongs WHERE urlStringFilesystemSafe = ? AND songId = ?", settingsS.urlStringFilesystemSafe, self.songId];
}

- (void)setIsFullyCached:(BOOL)isFullyCached {
	NSAssert(isFullyCached, @"Can not set isFullyCached to NO");
    
    if (isFullyCached) {
        [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"UPDATE offlineSong SET finished = 1, cachedDate = ?, size = ? WHERE urlStringFilesystemSafe = ? AND songId = ?", [NSDate date], @(self.localFileSize), settingsS.urlStringFilesystemSafe, self.songId];
        }];
        
        [self addToOfflineSongFolderLayout];
        [self removeFromDownloadQueue];
    }
}

- (CGFloat)downloadProgress {
    CGFloat downloadProgress = 0;
    if (self.isFullyCached) {
        downloadProgress = 1;
    } else {
        CGFloat bitrate = (CGFloat)self.estimatedBitrate;
        if (audioEngineS.player.isPlaying) {
            bitrate = [BassWrapper estimateBitrate:audioEngineS.player.currentStream];
        }
        
        CGFloat seconds = [self.duration floatValue];
        if (self.transcodedSuffix) {
            // This is a transcode, so we'll want to use the actual bitrate if possible
            if ([playQueueS.currentSong isEqualToSong:self]) {
                // This is the current playing song, so see if BASS has an actual bitrate for it
                if (audioEngineS.player.bitRate > 0) {
                    // Bass has a non-zero bitrate, so use that for the calculation
                    // convert to bytes per second, multiply by number of seconds
                    bitrate = (CGFloat)audioEngineS.player.bitRate;
                    seconds = [self.duration floatValue];
                }
            }
        }
        double totalSize = BytesForSecondsAtBitrate(bitrate, seconds);
        downloadProgress = (double)self.localFileSize / totalSize;
    }
    
    // Keep within bounds
    downloadProgress = downloadProgress < 0. ? 0. : downloadProgress;
    downloadProgress = downloadProgress > 1. ? 1. : downloadProgress;
    
    // The song hasn't started downloading yet
    return downloadProgress;
}

- (BOOL)fileExists {
    // Filesystem check
    return [[NSFileManager defaultManager] fileExistsAtPath:self.currentPath];
    
    // Database check
    //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
}

- (NSDate *)playedDate {
    NSString *query = @"SELECT playedDate FROM offlineSong WHERE urlStringFilesystemSafe = ? AND songId = ?";
    return [databaseS.offlineSongsDbQueue dateForQuery:query, settingsS.urlStringFilesystemSafe, self.songId];
}

- (void)setPlayedDate:(NSDate *)playedDate {
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"UPDATE cachedSongs SET playedDate = ? WHERE urlStringFilesystemSafe = ? AND songId = ?";
        [db executeUpdate:query, playedDate, settingsS.urlStringFilesystemSafe, self.songId];
    }];
}

- (BOOL)isCurrentPlayingSong {
    if (settingsS.isJukeboxEnabled) {
        return jukeboxS.isPlaying && [self isEqualToSong:playQueueS.currentSong];
    } else {
        return [self isEqualToSong:audioEngineS.player.currentStream.song];
    }
}

#pragma mark Retrieve

- (nullable instancetype)initWithSongId:(NSString *)songId {
    __block ISMSSong *song = nil;
    [databaseS.serverDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM song WHERE songId = ?", songId];
        if ([result next]) {
            song = [[ISMSSong alloc] initWithResult:result];
        } else if (db.hadError) {
            DDLogError(@"[ISMSSong+DAO] Error selecting song using songId %@ - %d: %@", songId, db.lastErrorCode, db.lastErrorMessage);
        }
        [result close];
    }];
    return song;
}

+ (ISMSSong *)songAtPosition:(NSUInteger)itemOrder inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue {
    __block ISMSSong *song = nil;
    [dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"SELECT song.* FROM %@ JOIN song ON %@.songId = song.songId WHERE %@.itemOrder = %lu", table, table, table, (unsigned long)itemOrder];
        FMResultSet *result = [db executeQuery:query];
        if ([result next]) {
            song = [[ISMSSong alloc] initWithResult:result];
        } else if (db.hadError) {
            DDLogError(@"[ISMSSong+DAO] Error selecting song at position %lu in table %@ - %d: %@", (unsigned long)itemOrder, table, db.lastErrorCode, db.lastErrorMessage);
        }
        [result close];
    }];
    return song;
}

+ (ISMSSong *)songAtPositionInCurrentPlayQueue:(NSUInteger)itemOrder {
    NSString *table;
    if (settingsS.isJukeboxEnabled) {
        table = playQueueS.isShuffle ? @"jukeboxShufflePlaylist" : @"jukeboxCurrentPlaylist";
    } else {
        table = playQueueS.isShuffle ? @"shufflePlaylist" : @"currentPlaylist";
    }
    return [ISMSSong songAtPosition:itemOrder inTable:table inDatabaseQueue:databaseS.serverDbQueue];
}

+ (ISMSSong *)songAtPosition:(NSUInteger)itemOrder fromServerPlaylistId:(NSUInteger)playlistId {
	NSString *table = [NSString stringWithFormat:@"splaylist%lu", (unsigned long)playlistId];
    return [ISMSSong songAtPosition:itemOrder inTable:table inDatabaseQueue:databaseS.serverDbQueue];
}

+ (ISMSSong *)downloadedSongWithUrlStringFilesystemSafe:(NSString *)urlStringFilesystemSafe songId:(NSString *)songId {
    __block ISMSSong *song = nil;
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT song.* FROM offlineSong JOIN song ON offlineSong.songId = song.songId WHERE offlineSong.urlStringFilesystemSafe = ? AND offlineSong.songId = ?";
        FMResultSet *result = [db executeQuery:query, urlStringFilesystemSafe, songId];
        if ([result next]) {
            song = [[ISMSSong alloc] initWithResult:result];
        } else if (db.hadError) {
            DDLogError(@"[ISMSSong+DAO] Error selecting song from offline songs table - %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
        [result close];
    }];
    return song;
}

+ (ISMSSong *)songAtPositionInDownloadQueue:(NSUInteger)itemOrder {
    return [self songAtPosition:itemOrder inTable:@"downloadQueue" inDatabaseQueue:databaseS.serverDbQueue];
}

#pragma mark Store and Delete

- (BOOL)addToOfflineSongs {
	__block BOOL hadError = NO;
	[databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"REPLACE INTO offlineSong (urlStringFilesystemSafe, songId, finished, pinned, size, cachedDate, playedDate) VALUES (?, ?, 0, 0, 0, ?, 0)";
        if (![db executeUpdate:query, settingsS.urlStringFilesystemSafe, self.songId, [NSDate date]]) {
            hadError = YES;
            DDLogError(@"[ISMSSong+DAO] Error inserting into offlineSong table - %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
	}];
	return !hadError;
}

- (BOOL)addToOfflineSongFolderLayout {
    // Save the offline view layout info
    __block BOOL hadError = NO;
    NSArray *pathComponents = [self.path componentsSeparatedByString:@"/"];
    NSString *urlStringFilesystemSafe = settingsS.urlStringFilesystemSafe;
    NSString *songId = self.songId;
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if ([db beginTransaction]) {
            for (int i = 0; i < pathComponents.count; i++) {
                NSString *query = @"INSERT INTO offlineSongFolderLayout (urlStringFilesystemSafe, songId, level, pathSegment) VALUES (?, ?, ?, ?)";
                if (![db executeUpdate:query, urlStringFilesystemSafe, songId, @(i), pathComponents[i]]) {
                    hadError = YES;
                    break;
                }
            }
            
            if (!hadError) {
                if (![db commit]) {
                    hadError = YES;
                }
            }
        } else {
            hadError = YES;
        }
        
        if (hadError) {
            [db rollback];
            DDLogError(@"[Song+DAO] Failed to update offline songs folder layout - %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

// TODO: Refactor this to share code with class method
- (BOOL)removeFromOfflineSongs {
    // Check if we're deleting the song that's currently playing. If so, stop the player.
    // TODO: Make sure currentSong check takes into account server url somehow
    if (playQueueS.currentSong && !settingsS.isJukeboxEnabled && [playQueueS.currentSong isEqualToSong:self]) {
        [audioEngineS.player stop];
    }
    
    __block BOOL hadError = NO;
    NSString *urlStringFilesystemSafe = settingsS.urlStringFilesystemSafe;
    NSString *songId = self.songId;
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSArray *queries = @[@"DELETE FROM offlineSong WHERE urlStringFilesystemSafe = ? AND songId = ?",
                             @"DELETE FROM offlineSongFolderLayout WHERE urlStringFilesystemSafe = ? AND songId = ?",
                             @"DELETE FROM song WHERE urlStringFilesystemSafe = ? AND songId = ?"];
        
        if ([db beginTransaction]) {
            for (NSString *query in queries) {
                if (![db executeUpdate:query, urlStringFilesystemSafe, songId]) {
                    hadError = YES;
                    break;
                }
            }
            
            if (!hadError) {
                if (![db commit]) {
                    hadError = YES;
                }
            }
        } else {
            hadError = YES;
        }
        
        if (hadError) {
            [db rollback];
            DDLogError(@"[Song+DAO] Failed to delete offline song from db - %d - %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    
    // Delete the song from disk
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.localPath error:&error];
    if (error) {
        DDLogError(@"[Song+DAO] Failed to delete offline song from disk - %@", error);
        hadError = YES;
    }
    
    // TODO: Why is this here?
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    return !hadError;
}

+ (BOOL)removeFromOfflineSongsWithUrlStringFilesystemSafe:(NSString *)urlStringFilesystemSafe songId:(NSString *)songId {
    // Check if we're deleting the song that's currently playing. If so, stop the player.
    if (!settingsS.isJukeboxEnabled && [settingsS.urlStringFilesystemSafe isEqualToString:urlStringFilesystemSafe] && [songId isEqualToString:playQueueS.currentSong.songId]) {
        [audioEngineS.player stop];
    }
    
    NSString *path = [databaseS.offlineSongsDbQueue stringForQuery:@"SELECT path FROM song WHERE urlStringFilesystemSafe = ? AND songId = ?", urlStringFilesystemSafe, songId];
    
    __block BOOL hadError = NO;
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSArray *queries = @[@"DELETE FROM offlineSong WHERE urlStringFilesystemSafe = ? AND songId = ?",
                             @"DELETE FROM offlineSongFolderLayout WHERE urlStringFilesystemSafe = ? AND songId = ?",
                             @"DELETE FROM song WHERE urlStringFilesystemSafe = ? AND songId = ?"];
        
        if ([db beginTransaction]) {
            for (NSString *query in queries) {
                if (![db executeUpdate:query, urlStringFilesystemSafe, songId]) {
                    hadError = YES;
                    break;
                }
            }
            
            if (!hadError) {
                if (![db commit]) {
                    hadError = YES;
                }
            }
        } else {
            hadError = YES;
        }
        
        if (hadError) {
            [db rollback];
            DDLogError(@"[Song+DAO] Failed to delete offline song from db - %d - %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    
    // Delete the song from disk
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error) {
        DDLogError(@"[Song+DAO] Failed to delete offline song from disk - %@", error);
        hadError = YES;
    }
    
    // TODO: Why is this here?
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    return !hadError;
}

- (BOOL)addToDownloadQueue {
    if (self.isFullyCached) return NO;
    
    __block BOOL hadError = NO;
    [databaseS.serverDbQueue inDatabase:^(FMDatabase *db) {
        NSUInteger itemOrder = [db intForQuery:@"SELECT MAX(itemOrder) + 1 FROM downloadQueue"];
        NSString *query = @"INSERT OR IGNORE INTO downloadQueue (songId, itemOrder) VALUES (?, ?)";
        [db executeUpdate:query, self.songId, @(itemOrder)];
    }];
    
    if (!hadError && !cacheQueueManagerS.isQueueDownloading) {
        // TODO: Confirm if this actually needs to be on the main thread now (I don't think it does)
        [EX2Dispatch runInMainThreadAsync:^{
            [cacheQueueManagerS startDownloadQueue];
        }];
    }
    
    return !hadError;
}

// TODO: Adjust itemOrder of all other items
- (BOOL)removeFromDownloadQueue {
	__block BOOL hadError;
	[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"DELETE FROM downloadQueue WHERE songId = ?", self.songId]) {
            hadError = YES;
            DDLogError(@"[ISMSSong+DAO] Error removing song from download queue table - %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
	}];
	return !hadError;
}

// TODO: Also add to current playlist when in shuffle mode so song is there when exiting shuffle mode
- (BOOL)addToCurrentPlayQueue {
    NSString *table;
    if (settingsS.isJukeboxEnabled) {
        table = playQueueS.isShuffle ? @"jukeboxShufflePlaylist" : @"jukeboxCurrentPlaylist";
    } else {
        table = playQueueS.isShuffle ? @"shufflePlaylist" : @"currentPlaylist";
    }
    
    __block BOOL hadError = NO;
    [databaseS.serverDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSUInteger itemOrder = [db intForQuery:[NSString stringWithFormat:@"SELECT MAX(itemOrder) + 1 FROM %@", table]];
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (songId, itemOrder) VALUES (?, ?)", table];
        if (![db executeUpdate:query, self.songId, @(itemOrder)]) {
            hadError = YES;
        }
    }];
    
    if (!hadError) {
        if (settingsS.isJukeboxEnabled) {
            [jukeboxS addSong:self.songId];
        } else {
            [streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
        }
    }
    
    return !hadError;
}

- (BOOL)addToShufflePlayQueue {
    NSString *table = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
    
    __block BOOL hadError = NO;
    [databaseS.serverDbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSUInteger itemOrder = [db intForQuery:[NSString stringWithFormat:@"SELECT MAX(itemOrder) + 1 FROM %@", table]];
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (songId, itemOrder) VALUES (?, ?)", table];
        if (![db executeUpdate:query, self.songId, @(itemOrder)]) {
            hadError = YES;
        }
    }];
    
    if (!hadError) {
        if (settingsS.isJukeboxEnabled) {
            [jukeboxS addSong:self.songId];
        } else {
            [streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
        }
    }
    
    return !hadError;
}

- (BOOL)updateMetadataCache {
    __block BOOL hadError;
    [databaseS.serverDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"REPLACE INTO song (%@) VALUES (%@)", ISMSSong.standardSongColumnNames, ISMSSong.standardSongColumnQMarks];
        [db executeUpdate:query, self.songId, self.title, self.artist, self.album, self.genre, self.coverArtId, self.parentId, self.tagArtistId, self.tagAlbumId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.discNumber, self.year, self.size, @(self.isVideo)];
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[ISMSSong+DAO] Error inserting song %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)updateOfflineMetadataCache {
    __block BOOL hadError;
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"REPLACE INTO song (urlStringFilesystemSafe, %@) VALUES (%@)", ISMSSong.standardSongColumnNames, ISMSSong.standardSongColumnQMarks];
        [db executeUpdate:query, settingsS.urlStringFilesystemSafe, self.songId, self.title, self.artist, self.album, self.genre, self.coverArtId, self.parentId, self.tagArtistId, self.tagAlbumId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.discNumber, self.year, self.size, @(self.isVideo)];
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[ISMSSong+DAO] Error inserting song %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

+ (NSString *)standardSongColumnSchema {
    return @"songId TEXT, title TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, parentId TEXT, tagArtistId TEXT, tagAlbumId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, isVideo INTEGER";
}

+ (NSString *)standardSongColumnNames {
    return @"songId, title, artist, album, genre, coverArtId, parentId, tagArtistId, tagAlbumId, path, suffix, transcodedSuffix, duration, bitRate, track, discNumber, year, size, isVideo";
}

+ (NSString *)standardSongColumnQMarks {
    return @"?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
}

@end
