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

@implementation SUSSubFolderDAO

#pragma mark - Lifecycle

- (void)setup {
    _albumStartRow = [self findFirstAlbumRow];
    _songStartRow = [self findFirstSongRow];
    _albumsCount = [self findAlbumsCount];
    _songsCount = [self findSongsCount];
    _folderLength = [self findFolderLength];
}

- (instancetype)init {
    if (self = [super init]) {
		[self setup];
    }
    return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate {
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
	return databaseS.albumListCacheDbQueue;
}

#pragma mark - Private DB Methods

- (NSUInteger)findFirstAlbumRow {
    return [self.dbQueue intForQuery:@"SELECT rowid FROM albumsCache WHERE folderId = ? LIMIT 1", self.folderId.md5];
}

- (NSUInteger)findFirstSongRow {
    return [self.dbQueue intForQuery:@"SELECT rowid FROM songsCache WHERE folderId = ? LIMIT 1", self.folderId.md5];
}

- (NSUInteger)findAlbumsCount {
    return [self.dbQueue intForQuery:@"SELECT count FROM albumsCacheCount WHERE folderId = ?", self.folderId.md5];
}

- (NSUInteger)findSongsCount {
    return [self.dbQueue intForQuery:@"SELECT count FROM songsCacheCount WHERE folderId = ?", self.folderId.md5];
}

- (NSUInteger)findFolderLength {
    return [self.dbQueue intForQuery:@"SELECT length FROM folderLength WHERE folderId = ?", self.folderId.md5];
}

- (ISMSFolderAlbum *)findFolderAlbumForDbRow:(NSUInteger)row {
    __block ISMSFolderAlbum *folderAlbum = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM albumsCache WHERE ROWID = %lu", (unsigned long)row]];
        if ([result next]) {
            folderAlbum = [[ISMSFolderAlbum alloc] initWithResult:result];
        } else if ([db hadError]) {
            // TODO: Handle error
            //DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
		[result close];
	}];
	return folderAlbum;
}

- (ISMSSong *)findSongForDbRow:(NSUInteger)row {
	return [ISMSSong songFromDbRow:row-1 inTable:@"songsCache" inDatabaseQueue:self.dbQueue];
}

- (ISMSSong *)playSongAtDbRow:(NSUInteger)row {
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
			ISMSSong *aSong = [self songForTableViewRow:i];
			//DLog(@"song parentId: %@", aSong.parentId);
			//DLog(@"adding song to playlist: %@", aSong);
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	// Set player defaults
	playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Start the song
	return [musicS playSongAtPosition:(row - self.songStartRow)];
}

#pragma mark - Public DAO Methods

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
    return [self findFolderAlbumForDbRow:dbRow];
}

- (ISMSSong *)songForTableViewRow:(NSUInteger)row {
    NSUInteger dbRow = self.songStartRow + (row - self.albumsCount);
    return [self findSongForDbRow:dbRow];
}

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row {
	NSUInteger dbRow = self.songStartRow + (row - self.albumsCount);
	return [self playSongAtDbRow:dbRow];
}

- (NSArray *)sectionInfo {
	// Create the section index
	if (self.albumsCount > 10) {
		__block NSArray *sectionInfo;
		[self.dbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
			[db executeUpdate:@"CREATE TEMPORARY TABLE albumIndex (title TEXT)"];
			
			[db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid >= ? LIMIT ?", @(self.albumStartRow), @(self.albumsCount)];
			[db executeUpdate:@"CREATE INDEX albumIndex_title ON albumIndex (title)"];
            
			sectionInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"title"];
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		}];
		return [sectionInfo count] < 2 ? nil : sectionInfo;
	}
	return nil;
}

#pragma mark - Loader Manager Methods

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

#pragma mark - Loader Delegate Methods

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
