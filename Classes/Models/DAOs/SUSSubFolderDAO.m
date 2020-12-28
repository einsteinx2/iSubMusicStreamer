//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "SUSSubFolderLoader.h"
#import "MusicSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation SUSSubFolderDAO

#pragma mark Lifecycle

- (instancetype)init {
    NSAssert(NO, @"[SUSSubFolderDAO] init should never be called");
    return nil;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andId:(NSString *)folderId andFolderArtist:(ISMSFolderArtist *)folderArtist {
	if (self = [super init]) {
		_delegate = delegate;
		_folderArtist = folderArtist;
        _folderMetadata = [self folderMetadataForFolderId:folderId];
    }
    return self;
}

- (void)dealloc {
	[_loader cancelLoad];
	_loader.delegate = nil;
}

- (FMDatabaseQueue *)dbQueue {
	return databaseS.serverDbQueue;
}

- (ISMSFolderMetadata *)folderMetadataForFolderId:(NSString *)folderId {
    __block ISMSFolderMetadata *folderMetadata = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM folderMetadata WHERE folderId = ?", folderId];
        if ([result next]) {
            folderMetadata = [[ISMSFolderMetadata alloc] initWithResult:result];
        } else if (db.hadError) {
            // TODO: Handle error
            DDLogError(@"[SUSSubFolderDAO] Error reading folderMetadata %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
        [result close];
    }];
    return folderMetadata;
}

#pragma mark Public DAO Methods

- (BOOL)hasLoaded {
    if (self.folderMetadata.subfolderCount > 0 || self.folderMetadata.songCount > 0)
        return YES;
    
    return NO;
}

- (NSUInteger)totalCount {
    return self.folderMetadata.subfolderCount + self.folderMetadata.songCount;
}

- (NSUInteger)albumsCount {
    return self.folderMetadata.subfolderCount;
}

- (NSUInteger)songsCount {
    return self.folderMetadata.songCount;
}

- (NSUInteger)duration {
    return self.folderMetadata.duration;
}

- (ISMSFolderAlbum *)folderAlbumForTableViewRow:(NSUInteger)row {
    NSUInteger itemOrder = row;
    __block ISMSFolderAlbum *folderAlbum = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM folderAlbum WHERE folderId = ? AND itemOrder = ?", self.folderMetadata.folderId, @(itemOrder)];
        if ([result next]) {
            folderAlbum = [[ISMSFolderAlbum alloc] initWithResult:result];
        } else if (db.hadError) {
            // TODO: Handle error
            DDLogError(@"[SUSSubFolderDAO] Error reading folderAlbum %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
        [result close];
    }];
    return folderAlbum;
}

- (ISMSSong *)songForTableViewRow:(NSUInteger)row {
    NSUInteger itemOrder = row - self.folderMetadata.subfolderCount;
    __block ISMSSong *song = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT song.* FROM folderSong JOIN song ON folderSong.songId = song.songId WHERE folderSong.folderId = ? AND folderSong.itemOrder = ?", self.folderMetadata.folderId, @(itemOrder)];
        song = [ISMSSong songFromDbResult:result];
        [result close];
    }];
    return song;
}

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row {
    // Clear the current playlist
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    
    // Add the songs to the playlist
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO currentPlaylist SELECT songId, itemOrder FROM folderSong WHERE folderId = ? ORDER BY itemOrder ASC", self.folderMetadata.folderId];
        if (db.hadError) {
            // TODO: Handle error
            DDLogError(@"[SUSSubFolderDAO] Error inserting folder %@'s songs into current playlist %d: %@", self.folderMetadata.folderId, db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    
    // Set player defaults
    playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    // Start the song
    return [musicS playSongAtPosition:(self.folderMetadata.subfolderCount - row)];
}

// TODO: Run EXPLAIN QUERY PATH on the query used in sectionInfoFromTableWithOrderColumn to confirm the title index works and doesn't need to be an FTS3 index
- (NSArray *)sectionInfo {
	// Create the section index
	if (self.folderMetadata.subfolderCount > 10) {
		__block NSArray *sectionInfo;
		[self.dbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS folderIndex"];
			[db executeUpdate:@"CREATE TEMPORARY TABLE folderIndex (title TEXT, order INTEGER)"];
			
			[db executeUpdate:@"INSERT INTO folderIndex SELECT title, order FROM folderAlbum WHERE folderId = ?", self.folderMetadata.folderId];
			[db executeUpdate:@"CREATE INDEX folderIndex_title ON folderIndex (title)"];
            
			sectionInfo = [databaseS sectionInfoFromTableWithItemOrderColumn:@"folderIndex" inDatabase:db withColumn:@"title"];
			[db executeUpdate:@"DROP TABLE folderIndex"];
		}];
		return sectionInfo.count < 2 ? nil : sectionInfo;
	}
	return nil;
}

#pragma mark Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSSubFolderLoader alloc] initWithDelegate:self];
    self.loader.folderId = self.folderMetadata.folderId;
    self.loader.folderArtist = self.folderArtist;
    [self.loader startLoad];
}

- (void)cancelLoad {
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)]) {
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    self.folderMetadata = [self folderMetadataForFolderId:self.loader.folderId];
	
    self.loader.delegate = nil;
    self.loader = nil;
    
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
		[self.delegate loadingFinished:nil];
	}
}

@end
