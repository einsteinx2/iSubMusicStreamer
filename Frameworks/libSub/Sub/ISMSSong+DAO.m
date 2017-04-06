//
//  Song+DAO.m
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSSong+DAO.h"
#import "FMDatabaseQueue.h"

#import "PlaylistSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSStreamManager.h"
#import "BassGaplessPlayer.h"

@implementation ISMSSong (DAO)

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.songCacheDbQueue;
}

- (BOOL)fileExists
{
	// Filesystem check
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.currentPath]; 
	//DLog(@"fileExists: %@  at path: %@", NSStringFromBOOL(fileExists), self.currentPath);
	return fileExists;
	
	// Database check
	//return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
}

- (BOOL)isPartiallyCached
{
	__block BOOL isPartiallyCached;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		 isPartiallyCached = [db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? AND finished = 'NO'", [self.path md5]] ? YES : NO;
	}];
	return isPartiallyCached; 
}

- (void)setIsPartiallyCached:(BOOL)isPartiallyCached
{
	assert(isPartiallyCached && "Can not set isPartiallyCached to to NO");
	if (isPartiallyCached)
	{
		[self insertIntoCachedSongsTableDbQueue];
	}
}

- (BOOL)isFullyCached
{	
	__block BOOL isFullyCached;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		isFullyCached = [[db stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", [self.path md5]] boolValue];
	}];
	return isFullyCached;
}

- (void)setIsFullyCached:(BOOL)isFullyCached
{
	assert(isFullyCached && "Can not set isFullyCached to NO");
	if (isFullyCached)
	{
		//DLog(@"%@: UPDATE cachedSongs SET finished = 'YES', cachedDate = %llu WHERE md5 = '%@'", self.title, (unsigned long long)[[NSDate date] timeIntervalSince1970], [self.path md5]);
		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"UPDATE cachedSongs SET finished = 'YES', cachedDate = ? WHERE md5 = ?", @((unsigned long long)[[NSDate date] timeIntervalSince1970]), [self.path md5]];
            
            // get the file path so we can check its size
            NSString *path = [settingsS.songCachePath stringByAppendingPathComponent:self.path.md5];
            
            // get the attributes dictionary
            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            [db executeUpdate:@"REPLACE INTO sizesSongs VALUES (?, ?)", self.path.md5, attr[NSFileSize]];
            ALog(@"Size for song \"%@\" successfully added to database on cache completion", self.title);
		}];
		
		[self insertIntoCachedSongsLayoutDbQueue];
		
		// Setup the genre table entries
		if (self.genre)
		{
			// Check if the genre has a table in the database yet, if not create it and add the new genre to the genres table
			[self.dbQueue inDatabase:^(FMDatabase *db)
			{
				NSString *genre = [db stringForQuery:@"SELECT genre FROM genres WHERE genre = ?", self.genre];
				if (genre)
				{							
					[db executeUpdate:@"INSERT OR IGNORE INTO genres (genre) VALUES (?)", self.genre];
					if ([db hadError])
						DLog(@"Err adding the genre %d: %@", [db lastErrorCode], [db lastErrorMessage]); 
				}
			}];
			
			// Insert the song object into the appropriate genresSongs table
			[self insertIntoGenreTable:@"genresSongs" inDatabaseQueue:self.dbQueue];
		}
		
		[self removeFromCacheQueueDbQueue];
	}
}

+ (ISMSSong *)songFromDbResult:(FMResultSet *)result
{
	ISMSSong *aSong = nil;
	if ([result next])
	{
		aSong = [[ISMSSong alloc] init];
		aSong.title = [result stringForColumn:@"title"];
		aSong.songId = [result stringForColumn:@"songId"];
		aSong.parentId = [result stringForColumn:@"parentId"];
		aSong.artist = [result stringForColumn:@"artist"];
		aSong.album = [result stringForColumn:@"album"];
		aSong.genre = [result stringForColumn:@"genre"];
		aSong.coverArtId = [result stringForColumn:@"coverArtId"];
		aSong.path = [result stringForColumn:@"path"];
		aSong.suffix = [result stringForColumn:@"suffix"];
		aSong.transcodedSuffix = [result stringForColumn:@"transcodedSuffix"];
		aSong.duration = @([result intForColumn:@"duration"]);
		aSong.bitRate = @([result intForColumn:@"bitRate"]);
		aSong.track = @([result intForColumn:@"track"]);
		aSong.year = @([result intForColumn:@"year"]);
		aSong.size = @([result intForColumn:@"size"]);
        if ([result stringForColumn:@"isVideo"] != nil)
            aSong.isVideo = [[result stringForColumn:@"isVideo"] boolValue];
        if ([result stringForColumn:@"discNumber"] != nil)
            aSong.discNumber = @([result intForColumn:@"discNumber"]);
	}
	
	return aSong;
}

+ (ISMSSong *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block ISMSSong *aSong;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		aSong = [ISMSSong songFromDbRow:row inTable:table inDatabase:db];
	}];
	return aSong;
}

+ (ISMSSong *)songFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	ISMSSong *aSong = nil;
	//DLog(@"query: %@", [NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %i", table, row]);
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %lu", table, (unsigned long)row]];
	if ([db hadError]) 
	{
	//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		aSong = [ISMSSong songFromDbResult:result];
	}
	[result close];
	
	return aSong;
}

+ (ISMSSong *)songFromAllSongsDb:(NSUInteger)row inTable:(NSString *)table
{
	return [ISMSSong songFromDbRow:row inTable:table inDatabaseQueue:databaseS.allSongsDbQueue];
}

+ (ISMSSong *)songFromServerPlaylistId:(NSString *)md5 row:(NSUInteger)row
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [ISMSSong songFromDbRow:row inTable:table inDatabaseQueue:databaseS.localPlaylistsDbQueue];
}

+ (ISMSSong *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block ISMSSong *aSong;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		aSong = [ISMSSong songFromDbForMD5:md5 inTable:table inDatabase:db];
	}];
	return aSong;
}

+ (ISMSSong *)songFromDbForMD5:(NSString *)md5 inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	ISMSSong *aSong = nil;
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE md5 = ?", table], md5];
	if ([db hadError]) 
	{
	//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		aSong = [ISMSSong songFromDbResult:result];
	}
	[result close];
	
	return aSong;
}

+ (ISMSSong *)songFromGenreDb:(FMDatabase *)db md5:(NSString *)md5
{
	return [ISMSSong songFromDbForMD5:md5 inTable:@"genresSongs" inDatabase:db];
}

+ (ISMSSong *)songFromGenreDbQueue:(NSString *)md5
{
	FMDatabaseQueue *dbQueue = settingsS.isOfflineMode ? databaseS.songCacheDbQueue : databaseS.genresDbQueue;
	return [ISMSSong songFromDbForMD5:md5 inTable:@"genresSongs" inDatabaseQueue:dbQueue];
}

+ (ISMSSong *)songFromCacheDb:(FMDatabase *)db md5:(NSString *)md5
{
	return [self songFromDbForMD5:md5 inTable:@"cachedSongs" inDatabase:db];
}

+ (ISMSSong *)songFromCacheDbQueue:(NSString *)md5
{
	return [self songFromDbForMD5:md5 inTable:@"cachedSongs" inDatabaseQueue:databaseS.songCacheDbQueue];
}

- (BOOL)insertIntoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block BOOL success;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		success = [self insertIntoTable:table inDatabase:db];
	}];
	return success;
}

- (BOOL)insertIntoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", table, [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId, NSStringFromBOOL(self.isVideo), self.discNumber];
	
	if ([db hadError]) 
	{
	//DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (BOOL)insertIntoServerPlaylistWithPlaylistId:(NSString *)md5
{
	NSString *table = [NSString stringWithFormat:@"splaylist%@", md5];
	return [self insertIntoTable:table inDatabaseQueue:databaseS.localPlaylistsDbQueue];
}

- (BOOL)insertIntoFolderCacheForFolderId:(NSString *)folderId
{
	__block BOOL hadError;
	[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], [folderId md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId, NSStringFromBOOL(self.isVideo), self.discNumber];
        
        ALog(@"Added to songsCache with folderCache: %@", self.discNumber);

		
		hadError = [db hadError];
		if (hadError)
		{
		//DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
	}];
	return !hadError;
}

- (BOOL)insertIntoGenreTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{	
	__block BOOL hadError;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		hadError = [self insertIntoGenreTable:table inDatabase:db];
	}];
	
	return !hadError;
}

- (BOOL)insertIntoGenreTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	BOOL hadError;
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (md5, %@) VALUES (?, %@)", table, [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], [self.path md5], self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId, NSStringFromBOOL(self.isVideo), self.discNumber];
    
    hadError = [db hadError];
    if (hadError)
    {
        ALog(@"Err inserting song into genre table %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
	
	return !hadError;
}

- (BOOL)insertIntoCachedSongsTableDbQueue
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		BOOL success = [db executeUpdate:[NSString stringWithFormat:@"REPLACE INTO cachedSongs (md5, finished, cachedDate, playedDate, %@) VALUES (?, 'NO', ?, 0, %@)",  [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], [self.path md5], @((unsigned long long)[[NSDate date] timeIntervalSince1970]), self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId, NSStringFromBOOL(self.isVideo), self.discNumber];
        
        ALog(@"Inserted into cachedSongs with discNumber: %@ and insert was successful? %d", self.discNumber, success);
		
		hadError = [db hadError];
		if (hadError) 
		{
		//DLog(@"Err inserting song into cached songs table %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
	}];
	return !hadError;
}

- (BOOL)removeFromCachedSongsTableDbQueue
{
	return [ISMSSong removeSongFromCacheDbQueueByMD5:[self.path md5]];
	
	// TODO: Figure out why the fuck I was doing this instead of calling the class method
	// this causes an orphaned file to be created whenever a stream is canceled part-way done
	/*DLog(@"removing %@ from cachedSongs", self.title);
	[self.db executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", [self.path md5]];
	
	if ([self.db hadError]) 
	{
	//DLog(@"Err removing song from cached songs table %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]);
	}
	
	return ![self.db hadError];*/
}

- (BOOL)removeFromCacheQueueDbQueue
{
	__block BOOL hadError;
	[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DELETE FROM cacheQueue WHERE md5 = ?", [self.path md5]];
		
		hadError = [db hadError];
		if (hadError) 
		{
		//DLog(@"Err removing song from cache queue table %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
	}];
	return !hadError;
}

- (BOOL)addToCacheQueueDbQueue
{	
	__block BOOL hadError;
	__block NSString *md5;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		md5 = [db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ? AND finished = 'YES'", [self.path md5]];
		hadError = [db hadError];
	}];
	
	if (hadError)
		return NO;
	
	if (!md5)
	{
		[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
		{
			BOOL success = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO cacheQueue (md5, finished, cachedDate, playedDate, %@) VALUES (?, ?, ?, ?, %@)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], [self.path md5], @"NO", @((unsigned long long)[[NSDate date] timeIntervalSince1970]), @0, self.title, self.songId, self.artist, self.album, self.genre, self.coverArtId, self.path, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.year, self.size, self.parentId, NSStringFromBOOL(self.isVideo), self.discNumber];
            
            ALog(@"Added to cacheQueue with discNumber: %@ and insert was successful? %d", self.discNumber, success);
			
			hadError = [db hadError];
			if (hadError)
			{
			//DLog(@"Err adding song to cache queue %d: %@", [db lastErrorCode], [db lastErrorMessage]);
			}
		}];
	}

	if (!cacheQueueManagerS.isQueueDownloading)
	{
		// Make sure this is called from the main thread
		if ([NSThread isMainThread])
			[cacheQueueManagerS startDownloadQueue];
		else
			[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [cacheQueueManagerS startDownloadQueue]; }];
	}
	
	return !hadError;
}

- (BOOL)addToCurrentPlaylistDbQueue
{
	BOOL success = YES;
	
	if (settingsS.isJukeboxEnabled)
	{
		if (![self insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
			success = NO;

		if (playlistS.isShuffle)
		{
			if (![self insertIntoTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
				success = NO;
		}
		
		[jukeboxS jukeboxAddSong:self.songId];
	}
	else
	{
		if (![self insertIntoTable:@"currentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
			success = NO;

		if (playlistS.isShuffle)
		{
			if (![self insertIntoTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
				success = NO;
		}
		
		[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
	}
	
	return success;
}

- (BOOL)addToShufflePlaylistDbQueue
{
	BOOL success = YES;
	
	if (settingsS.isJukeboxEnabled)
	{
		if (![self insertIntoTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
			success = NO;
		
		[jukeboxS jukeboxAddSong:self.songId];
	}
	else
	{
		if (![self insertIntoTable:@"shufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue])
			success = NO;
		
		[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
	}
	
	return success;
}

- (BOOL)insertIntoCachedSongsLayoutDbQueue
{
	// Save the offline view layout info
	NSArray *splitPath = [self.path componentsSeparatedByString:@"/"];
	
	__block BOOL hadError = YES;
	
	if ([splitPath count] <= 9)
	{
		NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
		while ([segments count] < 9)
		{
			[segments addObject:@""];
		}
		
		NSString *query = @"INSERT INTO cachedSongsLayout (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:query, [self.path md5], self.genre, @(splitPath.count), [segments objectAtIndexSafe:0], [segments objectAtIndexSafe:1], [segments objectAtIndexSafe:2], [segments objectAtIndexSafe:3], [segments objectAtIndexSafe:4], [segments objectAtIndexSafe:5], [segments objectAtIndexSafe:6], [segments objectAtIndexSafe:7], [segments objectAtIndexSafe:8]];
			hadError = [db hadError];
		}];
	}
    
	return !hadError;
}

+ (BOOL)removeSongFromCacheDbQueueByMD5:(NSString *)md5
{
	// Check if we're deleting the song that's currently playing. If so, stop the player.
	if (playlistS.currentSong && !settingsS.isJukeboxEnabled &&
		[[playlistS.currentSong.path md5] isEqualToString:md5])
	{
		//DLog(@"stopping the player before deleting the file");
        [audioEngineS.player stop];
	}
		
	__block BOOL hadError = NO;	
	
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		// Get the song info
		FMResultSet *result = [db executeQuery:@"SELECT genre FROM cachedSongs WHERE md5 = ?", md5];
		[result next];
		NSString *genre = nil;
		if ([result stringForColumnIndex:0] != nil)
			genre = [NSString stringWithString:[result stringForColumn:@"genre"]];
		[result close];
		if ([db hadError])
			hadError = YES;
		
		// Delete the row from the cachedSongs and genresSongs
		[db executeUpdate:@"DELETE FROM cachedSongs WHERE md5 = ?", md5];
		if ([db hadError])
			hadError = YES;
		[db executeUpdate:@"DELETE FROM cachedSongsLayout WHERE md5 = ?", md5];
		if ([db hadError])
			hadError = YES;
		[db executeUpdate:@"DELETE FROM genresSongs WHERE md5 = ?", md5];
		if ([db hadError])
			hadError = YES;
        [db executeUpdate:@"DELETE FROM sizesSongs WHERE md5 = ?", md5];
		if ([db hadError])
			hadError = YES;
		
		// Clean up genres table
		NSString *genreTest = [db stringForQuery:@"SELECT genre FROM genresSongs WHERE genre = ? LIMIT 1", genre];
		if (!genreTest)
		{
			DLog(@"deleting from genres table");
			[db executeUpdate:@"DELETE FROM genres WHERE genre = ?", genre];
			if ([db hadError]) hadError = YES;
			
			[db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			[db executeUpdate:@"CREATE TABLE genresTemp (genre TEXT)"];
			if ([db hadError]) hadError = YES;
			DLog(@"created genres temp, error %i", hadError);
			[db executeUpdate:@"INSERT INTO genresTemp SELECT * FROM genres"];
			if ([db hadError]) hadError = YES;
			[db executeUpdate:@"DROP TABLE genres"];
			if ([db hadError]) hadError = YES;
			[db executeUpdate:@"ALTER TABLE genresTemp RENAME TO genres"];
			if ([db hadError]) hadError = YES;
			DLog(@"renamed genrestemp to genres, error %i", hadError);
			[db executeUpdate:@"CREATE UNIQUE INDEX genreNames ON genres (genre)"];
			if ([db hadError]) hadError = YES;
		}
	}];
	 
	// Delete the song from disk
	NSString *fileName = [settingsS.songCachePath stringByAppendingPathComponent:md5];
	//TODO://///// REWRITE TO CATCH THIS NSFILEMANAGER ERROR ///////////
	[[NSFileManager defaultManager] removeItemAtPath:fileName error:NULL];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	return !hadError;
}

- (CGFloat)downloadProgress
{
	CGFloat downloadProgress = 0.;
	
	if (self.isFullyCached)
		downloadProgress = 1.;
	
	if (self.isPartiallyCached)
	{		
		CGFloat bitrate = (CGFloat)self.estimatedBitrate;
		if (audioEngineS.player.isPlaying)
		{
			bitrate = [BassWrapper estimateBitrate:audioEngineS.player.currentStream];
		}
		
		CGFloat seconds = [self.duration floatValue];
		if (self.transcodedSuffix)
		{
			// This is a transcode, so we'll want to use the actual bitrate if possible
			if ([playlistS.currentSong isEqualToSong:self])
			{
				// This is the current playing song, so see if BASS has an actual bitrate for it
				if (audioEngineS.player.bitRate > 0)
				{
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

- (NSDate *)playedDate
{
	__block NSDate *playedDate;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSUInteger playedTime = [db intForQuery:@"SELECT playedDate FROM cachedSongs WHERE md5 = ?", self.path.md5];
		playedDate = [NSDate dateWithTimeIntervalSince1970:playedTime];
	}];
	return playedDate; 
}

- (void)setPlayedDate:(NSDate *)playedDate
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = @"UPDATE cachedSongs SET playedDate = ? WHERE md5 = ?";
		[db executeUpdate:query, @((unsigned long long)[playedDate timeIntervalSince1970]), self.path.md5];
	}];
}

+ (NSString *)standardSongColumnSchema
{
	return @"title TEXT, songId TEXT, artist TEXT, album TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, track INTEGER, year INTEGER, size INTEGER, parentId TEXT, isVideo TEXT, discNumber INTEGER";
}

+ (NSString *)standardSongColumnNames
{
	return @"title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, isVideo, discNumber";
}

+ (NSString *)standardSongColumnQMarks
{
	return @"?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
}

- (BOOL)isCurrentPlayingSong
{
	if (settingsS.isJukeboxEnabled)
	{
		return jukeboxS.jukeboxIsPlaying && [self isEqualToSong:playlistS.currentSong];
	}
	else
	{
		return [self isEqualToSong:audioEngineS.player.currentStream.song];
	}
}

@end
