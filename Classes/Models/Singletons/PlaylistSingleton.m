//
//  PlaylistSingleton.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "PlaylistSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation PlaylistSingleton

#pragma mark - Private DB Methods

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.currentPlaylistDbQueue;
}

#pragma mark - Public DAO Methods

- (void)resetCurrentPlaylist
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE currentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetShufflePlaylist
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE shufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)deleteSongs:(NSArray *)indexes
{	
	@autoreleasepool
	{		
		BOOL goToNextSong = NO;
		
		NSMutableArray *indexesMut = [NSMutableArray arrayWithArray:indexes];
		
		// Sort the multiDeleteList to make sure it's accending
		[indexesMut sortUsingSelector:@selector(compare:)];
		
		if (settingsS.isJukeboxEnabled)
		{
			if ([indexesMut count] == self.count)
			{
				[self resetCurrentPlaylist];
			}
			else
			{
				[self.dbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxTemp"];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxTemp(%@)", [ISMSSong standardSongColumnSchema]]];
					
					for (NSNumber *index in [indexesMut reverseObjectEnumerator])
					{
						@autoreleasepool
						{
							NSInteger rowId = [index integerValue] + 1;
							[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM jukeboxCurrentPlaylist WHERE ROWID = %ld", (long)rowId]];
						}
					}
					
					[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist"];
					[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
					[db executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
				}];
			}
		}
		else
		{
			if (self.isShuffle)
			{
				if ([indexesMut count] == self.count)
				{
					[databaseS resetCurrentPlaylistDb];
					self.isShuffle = NO;
				}
				else
				{
					[self.dbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"DROP TABLE IF EXISTS shuffleTemp"];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shuffleTemp(%@)", [ISMSSong standardSongColumnSchema]]];
						
						for (NSNumber *index in [indexesMut reverseObjectEnumerator])
						{
							@autoreleasepool 
							{
								NSInteger rowId = [index integerValue] + 1;
								[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM shufflePlaylist WHERE ROWID = %ld", (long)rowId]];
							}
						}
						
						[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist"];
						[db executeUpdate:@"DROP TABLE shufflePlaylist"];
						[db executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
					}];
				}
			}
			else
			{
				if ([indexesMut count] == self.count)
				{
					[databaseS resetCurrentPlaylistDb];
				}
				else
				{
					[self.dbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"DROP TABLE currentTemp"];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentTemp(%@)", [ISMSSong standardSongColumnSchema]]];
						
						for (NSNumber *index in [indexesMut reverseObjectEnumerator])
						{
							@autoreleasepool 
							{
								NSInteger rowId = [index integerValue] + 1;
								[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM currentPlaylist WHERE ROWID = %ld", (long)rowId]];
							}
						}
						
						[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist"];
						[db executeUpdate:@"DROP TABLE currentPlaylist"];
						[db executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
					}];
				}
			}
		}
		
		// Correct the value of currentPlaylistPosition
		// If the current song was deleted make sure to set goToNextSong so the next song will play
		if ([indexesMut containsObject:@(self.currentIndex)] && audioEngineS.player.isPlaying)
		{
			goToNextSong = YES;
		}
		
		// Find out how many songs were deleted before the current position to determine the new position
		NSInteger numberBefore = 0;
		for (NSNumber *index in indexesMut)
		{
			@autoreleasepool
			{
				if ([index integerValue] <= self.currentIndex)
				{
					numberBefore++;
				}
			}
		}
		self.currentIndex = self.currentIndex - numberBefore;
		if (self.currentIndex < 0)
			self.currentIndex = 0;
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
		
		if (goToNextSong)
		{
			if (self.currentIndex != 0)
				[self incrementIndex];
			[musicS playSongAtPosition:self.currentIndex];
		}
		else
		{
			if (!settingsS.isJukeboxEnabled)
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
		}
	}
}

- (ISMSSong *)songForIndex:(NSUInteger)index
{
	ISMSSong *aSong = nil;
	if (settingsS.isJukeboxEnabled)
	{
		if (self.isShuffle)
			aSong = [ISMSSong songFromDbRow:index inTable:@"jukeboxShufflePlaylist" inDatabaseQueue:self.dbQueue];
		else
			aSong = [ISMSSong songFromDbRow:index inTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:self.dbQueue];
	}
	else
	{
		if (self.isShuffle)
			aSong = [ISMSSong songFromDbRow:index inTable:@"shufflePlaylist" inDatabaseQueue:self.dbQueue];
		else
			aSong = [ISMSSong songFromDbRow:index inTable:@"currentPlaylist" inDatabaseQueue:self.dbQueue];
	}
	
	return aSong;
}

- (ISMSSong *)prevSong
{
	ISMSSong *aSong = nil;
	@synchronized(self.class)
	{
		if (self.currentIndex - 1 >= 0)
			aSong = [self songForIndex:self.currentIndex-1];
	}
	return aSong;
}

- (ISMSSong *)currentDisplaySong
{
	// Either the current song, or the previous song if we're past the end of the playlist
	ISMSSong *aSong = self.currentSong;
	if (!aSong)
		aSong = self.prevSong;
	return aSong;
}

- (ISMSSong *)currentSong
{
	return [self songForIndex:self.currentIndex];	
}

- (ISMSSong *)nextSong
{
	return [self songForIndex:self.nextIndex];
}

- (NSInteger)normalIndex
{
	@synchronized(self.class)
	{
		return normalIndex;
	}
}

- (void)setNormalIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		normalIndex = index;
	}
}

- (NSInteger)shuffleIndex
{
	@synchronized(self.class)
	{
		return shuffleIndex;
	}
}

- (void)setShuffleIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		shuffleIndex = index;
	}
}

- (NSInteger)currentIndex
{
	if (self.isShuffle)
		return self.shuffleIndex;
	
	return self.normalIndex;
}

- (void)setCurrentIndex:(NSInteger)index
{
	BOOL indexChanged = NO;
	if (self.isShuffle && self.shuffleIndex != index)
	{
		self.shuffleIndex = index;
		indexChanged = YES;
	}
	else if (self.normalIndex != index)
	{
		self.normalIndex = index;
		indexChanged = YES;
	}
	
	if (indexChanged)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistIndexChanged];
}

- (NSInteger)prevIndex
{
    NSInteger currentIndexTemp = self.currentIndex;
	switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatOne:
            return currentIndexTemp;
            break;
        case ISMSRepeatMode_RepeatAll:
            if (currentIndexTemp == 0)
                return self.count - 1;
            else
                return currentIndexTemp - 1;
            break;
        case ISMSRepeatMode_Normal:
            if (currentIndexTemp == 0)
                return currentIndexTemp;
            else
                return currentIndexTemp - 1;
        default:
            break;
    }
}

- (NSInteger)nextIndex
{
    NSInteger currentIndexTemp = self.currentIndex;
    switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatOne:
            return currentIndexTemp;
            break;
        case ISMSRepeatMode_RepeatAll:
            if ([self songForIndex:currentIndexTemp + 1])
                return currentIndexTemp + 1;
            else
                return 0;
            break;
        case ISMSRepeatMode_Normal:
            if (![self songForIndex:currentIndexTemp] && ![self songForIndex:currentIndexTemp + 1])
                return currentIndexTemp;
            else
                return currentIndexTemp + 1;
        default:
            break;
    }
}

- (NSUInteger)indexForOffset:(NSInteger)offset fromIndex:(NSInteger)index
{
	switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatAll:
            if (offset >= 0)
            {
                // This is done instead of just calculating based on count because count is expensive to get
                for (int i = 0; i < offset; i++)
                {
                    index = [self songForIndex:index + 1] ? index + 1 : 0;
                }
            }
            else
            {
                index = index + offset >= 0 ? index + offset : self.count + index + offset;
            }
            break;
        case ISMSRepeatMode_Normal:
            if (offset >= 0)
            {
                // This is done instead of just calculating based on count because count is expensive to get
                for (int i = 0; i < offset; i++)
                {
                    if (![self songForIndex:index] && ![self songForIndex:index + 1])
                        index = index;
                    else
                        index++;
                }
            }
            else
            {
                index = index + offset >= 0 ? index + offset : 0;
            }
            
            break;
        default:
            break;
    }
    
    return index;
}

- (NSUInteger)indexForOffsetFromCurrentIndex:(NSInteger)offset
{
	return [self indexForOffset:offset fromIndex:self.currentIndex];
}

// TODO: cache this into a variable and change only when needed
- (NSUInteger)count
{
	int count = 0;
	if (settingsS.isJukeboxEnabled)
	{
		if (self.isShuffle)
			count = [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM jukeboxShufflePlaylist"];
		else
			count = [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"];
	}
	else
	{
		if (self.isShuffle)
			count = [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM shufflePlaylist"];
		else
			count = [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM currentPlaylist"];
	}
	return count;
}

- (NSInteger)decrementIndex
{
	@synchronized(self.class)
	{
		self.currentIndex = self.prevIndex;
		return self.currentIndex;
	}
}

- (NSInteger)incrementIndex
{
	@synchronized(self.class)
	{
		self.currentIndex = self.nextIndex;
		return self.currentIndex;
	}
}

- (ISMSRepeatMode)repeatMode
{
	@synchronized(self.class)
	{
		return repeatMode;
	}
}

- (void)setRepeatMode:(ISMSRepeatMode)mode
{
	@synchronized(self.class)
	{
		if (repeatMode != mode)
		{
			repeatMode = mode;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_RepeatModeChanged];
		}
	}
}

- (void)shuffleToggle
{				
	if (self.isShuffle)
	{
		NSString *songId = self.currentSong.songId;

		self.isShuffle = NO;
		
		// Find the track position in the regular playlist
		NSString *tableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		NSString *query = [NSString stringWithFormat:@"SELECT ROWID FROM %@ WHERE songId = ? LIMIT 1", tableName];
		self.currentIndex = [self.dbQueue intForQuery:query, songId] - 1;
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
			[jukeboxS jukeboxPlaySongAtPosition:@0];
		}
				
		// Send a notification to update the playlist view
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
	else
	{
		ISMSSong *currentSong = self.currentSong;
		
		NSNumber *oldPlaylistPosition = @(self.currentIndex + 1);
		self.shuffleIndex = 0;
		self.isShuffle = YES;
		
		[self resetShufflePlaylist];
		[currentSong addToShufflePlaylistDbQueue];
		
		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			if (settingsS.isJukeboxEnabled)
			{
				[db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
			}
			else
			{
				[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist WHERE ROWID != ? ORDER BY RANDOM()", oldPlaylistPosition];
			}
		}];
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
			
			[jukeboxS jukeboxPlaySongAtPosition:@1];
			
			//self.isShuffle = NO;
		}
		
		// Send a notification to update the playlist view 
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
}

#pragma mark - Singleton methods

- (void)setup
{
	shuffleIndex = 0;
	normalIndex = 0;
	repeatMode = ISMSRepeatMode_Normal;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

+ (id)sharedInstance
{
    static PlaylistSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
