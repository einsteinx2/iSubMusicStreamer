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

- (void)setup {
    _albumStartRow = [self.dbQueue intForQuery:@"SELECT rowid FROM folderAlbum WHERE folderId = ? LIMIT 1", self.folderId];
    _songStartRow = [self.dbQueue intForQuery:@"SELECT rowid FROM folderSong WHERE folderId = ? LIMIT 1", self.folderId];
    _albumsCount = [self.dbQueue intForQuery:@"SELECT subfolderCount FROM folderMetadata WHERE folderId = ? LIMIT 1", self.folderId];
    _songsCount = [self.dbQueue intForQuery:@"SELECT songCount FROM folderMetadata WHERE folderId = ? LIMIT 1", self.folderId];
    _folderLength = [self.dbQueue intForQuery:@"SELECT duration FROM folderMetadata WHERE folderId = ? LIMIT 1", self.folderId];
}

- (instancetype)init {
    NSAssert(NO, @"[SUSSubFolderDAO] init should never be called");
    if (self = [super init]) {
		[self setup];
    }
    return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate {
    NSAssert(NO, @"[SUSSubFolderDAO] initWithDelegate should never be called");
    if (self = [super init]) {
		_delegate = delegate;
		[self setup];
    }
    return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andId:(NSString *)folderId andFolderArtist:(ISMSFolderArtist *)folderArtist {
	if (self = [super init]) {
		_delegate = delegate;
        _folderId = folderId;
		_folderArtist = folderArtist;
		[self setup];
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

#pragma mark Public DAO Methods

- (BOOL)hasLoaded {
    if (self.albumsCount > 0 || self.songsCount > 0)
        return YES;
    
    return NO;
}

- (NSUInteger)totalCount {
    return self.albumsCount + self.songsCount;
}

- (ISMSFolderAlbum *)folderAlbumForTableViewRow:(NSUInteger)row {
    NSUInteger dbRow = self.albumStartRow + row;
    __block ISMSFolderAlbum *folderAlbum = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM folderAlbum WHERE ROWID = %lu", (unsigned long)dbRow]];
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
    NSUInteger dbRow = self.songStartRow + (row - self.albumsCount);
    return [ISMSSong songFromDbRow:dbRow-1 inTable:@"folderSong"];
}

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row {
	NSUInteger dbRow = self.songStartRow + (row - self.albumsCount);
    
    // Clear the current playlist
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    
    // Add the songs to the playlist
    for (NSInteger i = self.albumsCount; i < self.totalCount; i++) {
        @autoreleasepool  {
            [[self songForTableViewRow:i] addToCurrentPlaylistDbQueue];
        }
    }
    
    // Set player defaults
    playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    // Start the song
    return [musicS playSongAtPosition:(dbRow - self.songStartRow)];
}

- (NSArray *)sectionInfo {
	// Create the section index
	if (self.albumsCount > 10) {
		__block NSArray *sectionInfo;
		[self.dbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS folderIndex"];
			[db executeUpdate:@"CREATE TEMPORARY TABLE folderIndex (title TEXT)"];
			
			[db executeUpdate:@"INSERT INTO folderIndex SELECT title FROM folderAlbum WHERE rowid >= ? LIMIT ?", @(self.albumStartRow), @(self.albumsCount)];
			[db executeUpdate:@"CREATE INDEX folderIndex_title ON folderIndex (title)"];
            
			sectionInfo = [databaseS sectionInfoFromTable:@"folderIndex" inDatabase:db withColumn:@"title"];
			[db executeUpdate:@"DROP TABLE folderIndex"];
		}];
		return [sectionInfo count] < 2 ? nil : sectionInfo;
	}
	return nil;
}

#pragma mark Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSSubFolderLoader alloc] initWithDelegate:self];
    self.loader.folderId = self.folderId;
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
	self.loader.delegate = nil;
	self.loader = nil;
	
    [self setup];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
		[self.delegate loadingFinished:nil];
	}
}

@end
