 //
//  SUSAllSongsLoader.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllSongsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "SUSRootFoldersDAO.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@interface SUSAllSongsLoader()
@property (strong) NSData *receivedData;
- (void)createLoadTempTables;
- (void)createLoadTables;
- (void)loadAlbumFolder;
- (void)loadSort;
- (void)loadFinish;
- (void)sendArtistNotification:(NSString *)artistName;
- (void)sendAlbumNotification:(NSString *)albumTitle;
- (void)sendSongNotification:(NSString *)songTitle;
@end

@implementation SUSAllSongsLoader

@synthesize receivedData=_receivedData;

static BOOL _isAllSongsLoading = NO;
+ (BOOL)isLoading { return _isAllSongsLoading; }
+ (void)setIsLoading:(BOOL)isLoading { _isAllSongsLoading = isLoading; }

- (void)setup {
    [super setup];
	_notificationTimeArtist = [[NSDate alloc] init];
	_notificationTimeAlbum = [[NSDate alloc] init];
	_notificationTimeSong = [[NSDate alloc] init];
}

- (SUSLoaderType)type {
    return SUSLoaderType_AllSongs;
}

#pragma mark Data loading

- (void)cancelLoad {
    if ([SUSAllSongsLoader isLoading])
    {
        settingsS.isCancelLoading = YES;
    }
}

- (void)startLoad {
	self.tempAlbumsCount = 0;
	self.tempSongsCount = 0;
	self.tempGenresCount = 0;
	self.tempGenresLayoutCount = 0;
	
	self.totalAlbumsProcessed = 0;
	self.totalSongsProcessed = 0;
	
	[SUSAllSongsLoader setIsLoading:YES];
	
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", settingsS.urlString]];
	[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	self.rootFolders = [[SUSRootFoldersDAO alloc] init];
	
	// Check to see if we need to create the tables
	if ((![databaseS.allAlbumsDbQueue tableExists:@"resumeLoad"] && ![databaseS.allSongsDbQueue tableExists:@"resumeLoad"]) ||
		[databaseS.allSongsDbQueue tableExists:@"restartLoad"]) {
		// Both of the resume tables don't exist, so that means this is a new load not a resume
		// Or the restartLoad table was created explicitly
		// So create the tables for the load
		[self createLoadTables];
	}
	[self createLoadTempTables];
	
	if ([databaseS.allAlbumsDbQueue tableExists:@"resumeLoad"]) {
		// The albums are still loading or are just starting
		self.iteration = -1;
		
		self.currentRow = [databaseS.allAlbumsDbQueue intForQuery:@"SELECT artistNum FROM resumeLoad"];
		self.artistCount = [databaseS.albumListCacheDbQueue intForQuery:@"SELECT count FROM rootFolderCount_all LIMIT 1"];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsLoadingArtists];
		
		[self loadAlbumFolder];	
	} else {
		// The songs are still loading or are just starting
		
		self.iteration = [databaseS.allSongsDbQueue intForQuery:@"SELECT iteration FROM resumeLoad"];
		
		if (self.iteration == 0) {
			self.currentRow = [databaseS.allSongsDbQueue intForQuery:@"SELECT albumNum FROM resumeLoad"];
			self.albumCount = [databaseS.allAlbumsDbQueue intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsLoadingAlbums];
			
			[self loadAlbumFolder];
		} else if (self.iteration < 4) {
			self.currentRow = [databaseS.allSongsDbQueue intForQuery:@"SELECT albumNum FROM resumeLoad"];
			self.albumCount = [databaseS.allAlbumsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM subalbums%ld", (long)self.iteration]];
			
			if (self.albumCount > 0) {
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsLoadingAlbums];
				[self loadAlbumFolder];
			} else {
				// The table is empty so do the load sort
				self.iteration = 4;
				[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", @(0), @(self.iteration)];
				}];
				
				[self loadSort];
			}
		} else if (self.iteration == 4) {
			[self loadSort];
		} else if (self.iteration == 5) {
			[self loadFinish];
		}
	}
}	

- (void)createLoadTempTables {
	[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
		[db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
	}];
	
	[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
		NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [ISMSSong standardSongColumnSchema]];
		[db executeUpdate:query];
	}];
	
	[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
		[db executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
		
		[db executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
		[db executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
        
        [db executeUpdate:@"DROP TABLE IF EXISTS genresSongsTemp"];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE genresSongsTemp (md5 TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
	}];
}

- (void)createLoadTables {
	@autoreleasepool  {
		// Remove the old databases
		[databaseS.allAlbumsDbQueue close]; databaseS.allAlbumsDbQueue = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", settingsS.databasePath, [settingsS.urlString md5]] error:NULL];
		[databaseS.allSongsDbQueue close]; databaseS.allSongsDbQueue = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@allSongs.db", settingsS.databasePath, [settingsS.urlString md5]] error:NULL];
		[databaseS.genresDbQueue close]; databaseS.genresDbQueue = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@genres.db", settingsS.databasePath, [settingsS.urlString md5]] error:NULL];
		
		// Recreate the databases
		[databaseS setupAllSongsDb];
		
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
			// Create allAlbums tables
			[db executeUpdate:@"CREATE TABLE resumeLoad (artistNum INTEGER, iteration INTEGER)"];
			[db executeUpdate:@"INSERT INTO resumeLoad (artistNum, iteration) VALUES (1, 0)"];
			[db executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
			[db executeUpdate:@"CREATE TABLE allAlbumsUnsorted(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE TABLE allAlbumsCount (count INTEGER)"];
			[db executeUpdate:@"CREATE TABLE allAlbumsUnsortedCount (count INTEGER)"];
			
			[db executeUpdate:@"CREATE TABLE subalbums1 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE TABLE subalbums2 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE TABLE subalbums3 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
			[db executeUpdate:@"CREATE TABLE subalbums4 (title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];

            // Configure for correct sorting (i.e. like the Finder)
            [db makeFunctionNamed:@"unaccented" arguments:1 block:^(void * _Nonnull context, int argc, void * _Nonnull * _Nonnull argv) {
                SqliteValueType type = [db valueType:argv[0]];
                if (type == SqliteValueTypeNull) {
                    [db resultNullInContext:context];
                    return;
                }
                if (type != SqliteValueTypeText) {
                    [db resultError:@"Expected text" context:context];
                    return;
                }

                NSStringCompareOptions options = NSCaseInsensitiveSearch | NSNumericSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch | NSDiacriticInsensitiveSearch;
                NSString* result = [[db valueString: argv[0]] stringByFoldingWithOptions: options locale: nil];
                if (result) {
                    [db resultString: result context:context];
                } else {
                    [db resultNullInContext: context];
                }
            }];
		}];
		
		// Initialize allSongs db
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
			// Create allSongs tables
			[db executeUpdate:@"CREATE TABLE resumeLoad (albumNum INTEGER, iteration INTEGER)"];
			[db executeUpdate:@"INSERT INTO resumeLoad (albumNum, iteration) VALUES (1, 0)"];
			NSString *query = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (%@, tokenize=porter)", [ISMSSong standardSongColumnSchema]];
			[db executeUpdate:query];
			
			query = [NSString stringWithFormat:@"CREATE TABLE allSongsUnsorted (%@)", [ISMSSong standardSongColumnSchema]];
			[db executeUpdate:query];
			//[db executeUpdate:@"CREATE INDEX allSongsUnsorted_title ON allSongsUnsorted (title ASC)"];
			[db executeUpdate:@"CREATE TABLE allSongsCount (count INTEGER)"];
		}];
		
		// Initialize genres db
		[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
			// Create genres tables
			[db executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
			[db executeUpdate:@"CREATE TABLE genresUnsorted (genre TEXT UNIQUE)"];
			[db executeUpdate:@"CREATE TABLE genresLayout (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
            [db executeUpdate:@"CREATE INDEX genresLayout_genre_seg1 ON genresLayout (genre, seg1)"];
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
		}];
	}
}

- (void)loadAlbumFolder {
	// Check if loading should stop
	if (settingsS.isCancelLoading) {
		settingsS.isCancelLoading = NO;
		[SUSAllSongsLoader setIsLoading:NO];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", settingsS.urlString]];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self informDelegateLoadingFailed:nil];
		return;
	}
	
	if (self.iteration == -1) {
		self.currentArtist = [self.rootFolders artistForPosition:self.currentRow];
		[self sendArtistNotification:self.currentArtist.name];
	} else {
        if (self.iteration == 0) {
			self.currentAlbum = [databaseS albumFromDbRow:self.currentRow inTable:@"allAlbumsUnsorted" inDatabaseQueue:databaseS.allAlbumsDbQueue];
        } else {
			self.currentAlbum = [databaseS albumFromDbRow:self.currentRow inTable:[NSString stringWithFormat:@"subalbums%ld", (long)self.iteration] inDatabaseQueue:databaseS.allAlbumsDbQueue];
        }
		
		self.currentArtist = [ISMSArtist artistWithName:self.currentAlbum.artistName andArtistId:self.currentAlbum.artistId];
		
		[self sendAlbumNotification:self.currentAlbum.title];
	}
	
	NSString *dirId = nil;
    if (self.iteration == -1) {
		dirId = [self.currentArtist.artistId copy];
    } else {
		dirId = [self.currentAlbum.albumId copy];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:@{@"id": n2N(dirId)}];
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            // Load the same folder
            [self loadAlbumFolder];
            
            // Inform the delegate that loading failed
            [self informDelegateLoadingFailed:error];
        } else {
            self.receivedData = data;
            [self parseData];
        }
    }];
    [dataTask resume];
}

- (void)loadSortInternal {
	@autoreleasepool {
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
			// Sort the tables
			[db executeUpdate:@"DROP TABLE IF EXISTS allAlbums"];
			[db executeUpdate:@"CREATE VIRTUAL TABLE allAlbums USING FTS3(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT, tokenize=porter)"];
			[db executeUpdate:@"INSERT INTO allAlbums SELECT * FROM allAlbumsUnsorted ORDER BY unaccented(title)"];
		}];
		
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS allSongs"];
			NSString *query = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE allSongs USING FTS3 (%@, tokenize=porter)", [ISMSSong standardSongColumnSchema]];
			[db executeUpdate:query];
			[db executeUpdate:@"INSERT INTO allSongs SELECT * FROM allSongsUnsorted ORDER BY title COLLATE NOCASE"];
		}];
		
		[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE IF EXISTS genres"];
			[db executeUpdate:@"CREATE TABLE genres (genre TEXT UNIQUE)"];
			[db executeUpdate:@"INSERT INTO genres SELECT * FROM genresUnsorted ORDER BY genre COLLATE NOCASE"];
		}];
		
		// Clean up the tables
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", @0, @5];
			[db executeUpdate:@"DROP TABLE allSongsUnsorted"];
			[db executeUpdate:@"DROP TABLE allSongsTemp"];
		}];
		
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE allAlbumsUnsorted"];
			[db executeUpdate:@"DROP TABLE allAlbumsTemp"];
		}];
		
		[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE genresUnsorted"];
			[db executeUpdate:@"DROP TABLE genresTemp"];
		}];

		[self loadFinish];
	}
}

- (void)loadSort {
    if ([NSThread mainThread]) {
		[self performSelectorInBackground:@selector(loadSortInternal) withObject:nil];
    } else {
		[self loadSortInternal];
    }
}

- (void)loadFinishInternal {
	@autoreleasepool {
		// Check if loading should stop
        if (settingsS.isCancelLoading) {
            settingsS.isCancelLoading = NO;
			[SUSAllSongsLoader setIsLoading:NO];
			[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self informDelegateLoadingFailed:nil]; }];
            return;
        }
        
        // Create the section info array
		NSArray *sectionInfo = [databaseS sectionInfoFromTable:@"allAlbums" inDatabaseQueue:databaseS.allAlbumsDbQueue withColumn:@"title"];
		
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"DROP TABLE allAlbumsIndexCache"];
			[db executeUpdate:@"CREATE TABLE allAlbumsIndexCache (name TEXT, position INTEGER, count INTEGER)"];
			for (int i = 0; i < [sectionInfo count]; i++) {
				@autoreleasepool {
					NSArray *section = [sectionInfo objectAtIndexSafe:i];
					NSArray *nextSection = nil;
					if (i + 1 < [sectionInfo count])
						nextSection = [sectionInfo objectAtIndexSafe:i+1];
					
					NSString *name = [section objectAtIndexSafe:0];
					NSNumber *position = [section objectAtIndexSafe:1];
					NSNumber *count = nil;
                    if (nextSection) {
						count = @([[nextSection objectAtIndexSafe:1] intValue] - [position intValue]);
                    } else {
						count = @([db intForQuery:@"SELECT COUNT(*) FROM allAlbums WHERE ROWID > ?", position]);
                    }
                    
					[db executeUpdate:@"INSERT INTO allAlbumsIndexCache (name, position, count) VALUES (?, ?, ?)", name, position, count];
				}
			}
			
			// Count the table
			NSUInteger allAlbumsCount = 0;
			FMResultSet *result = [db executeQuery:@"SELECT count FROM allAlbumsIndexCache"];
			while ([result next]) {
				@autoreleasepool {
					allAlbumsCount += [result intForColumn:@"count"];
				}
			}
			[result close];
			[db executeUpdate:@"INSERT INTO allAlbumsCount VALUES (?)", @(allAlbumsCount)];
		}];
        
		// Create the section info array
        sectionInfo = [databaseS sectionInfoFromTable:@"allSongs" inDatabaseQueue:databaseS.allSongsDbQueue withColumn:@"title"];
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
            if ([db tableExists:@"allSongsIndexCache"]) {
                [db executeUpdate:@"DROP TABLE allSongsIndexCache"];
            }
			[db executeUpdate:@"CREATE TABLE allSongsIndexCache (name TEXT, position INTEGER, count INTEGER)"];
			for (int i = 0; i < sectionInfo.count; i++) {
				@autoreleasepool {
					NSArray *section = [sectionInfo objectAtIndexSafe:i];
					NSArray *nextSection = nil;
                    if (i + 1 < [sectionInfo count]) {
						nextSection = [sectionInfo objectAtIndexSafe:i+1];
                    }
					
					NSString *name = [section objectAtIndexSafe:0];
					NSNumber *position = [section objectAtIndexSafe:1];
					NSNumber *count = nil;
                    if (nextSection) {
						count = @([[nextSection objectAtIndexSafe:1] intValue] - [position intValue]);
                    } else {
						count = @([db intForQuery:@"SELECT COUNT(*) FROM allSongs WHERE ROWID > ?", position]);
                    }
                    
					[db executeUpdate:@"INSERT INTO allSongsIndexCache (name, position, count) VALUES (?, ?, ?)", name, position, count];
				}
			}
			
			// Count the table
			NSUInteger allSongsCount = 0;
			FMResultSet *result = [db executeQuery:@"SELECT count FROM allSongsIndexCache"];
			while ([result next]) {
				@autoreleasepool {
					allSongsCount += [result intForColumn:@"count"];
				}
			}
			[result close];
			[db executeUpdate:@"INSERT INTO allSongsCount VALUES (?)", @(allSongsCount)];
		}];
				
		// Check if loading should stop
        if (settingsS.isCancelLoading) {
            [SUSAllSongsLoader setIsLoading:NO];
			[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self informDelegateLoadingFailed:nil]; }];
			settingsS.isCancelLoading = NO;
            return;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@songsReloadTime", settingsS.urlString]];
        [defaults synchronize];
        
		[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
			[db executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", @0, @6];
			[db executeUpdate:@"DROP TABLE resumeLoad"];
		}];
      		
		[SUSAllSongsLoader setIsLoading:NO];
        settingsS.isCancelLoading = NO;
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllAlbumsLoading", settingsS.urlString]];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self informDelegateLoadingFinished]; }];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsLoadingFinished];
    }
}

- (void)loadFinish
{
    if ([NSThread isMainThread]) {
		[self performSelectorInBackground:@selector(loadFinishInternal) withObject:nil];
    } else {
		[self loadFinishInternal];
    }
}

- (NSArray *)createSectionInfo {
	__block NSMutableArray *sections = [[NSMutableArray alloc] init];
	[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:@"SELECT * FROM sectionInfo"];
		while ([result next]) {
			@autoreleasepool {
				NSString *name = [result stringForColumnIndex:0];
				NSNumber *index = [result objectForColumnIndex:1];
				
				if (name && index) {
					[sections addObject:@[name, index]];
				}
			}
		}
		[result close];
	}];
	return [NSArray arrayWithArray:sections];	
}

- (void)sendArtistNotification:(NSString *)artistName {
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeArtist] > 1.) {
		self.notificationTimeArtist = [NSDate date];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsArtistName object:[artistName copy]];
	}
}

- (void)sendAlbumNotification:(NSString *)albumTitle {
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeAlbum] > 1.) {
		self.notificationTimeAlbum = [NSDate date];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsAlbumName object:[albumTitle copy]];
	}
}

- (void)sendSongNotification:(NSString *)songTitle {
	if ([[NSDate date] timeIntervalSinceDate:self.notificationTimeSong] > 1.) {
		self.notificationTimeSong = [NSDate date];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AllSongsSongName object:[songTitle copy]];
	}
}

#pragma mark Connection Delegate

static NSString *kName_Directory = @"directory";
static NSString *kName_Child = @"child";
static NSString *kName_Error = @"error";

- (void)parseData {
	@autoreleasepool  {
        RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
        if (!root.isValid) {
            NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
            [self informDelegateLoadingFailed:error];
        } else {
            RXMLElement *error = [root child:@"error"];
            if (error.isValid) {
                NSInteger code = [[error attribute:@"code"] integerValue];
                NSString *message = [error attribute:@"message"];
                [self informDelegateLoadingFailed:[NSError errorWithISMSCode:code message:message]];
            } else {
                [root iterate:@"directory.child" usingBlock:^(RXMLElement *child) {
                    @autoreleasepool {
                        if ([[child attribute:@"isDir"] isEqualToString:@"true"]) {
                            // Initialize the Album
                            ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:child artistId:self.currentArtist.artistId artistName:self.currentArtist.name];
                            
                            // Skip if it's .AppleDouble, otherwise process it
                            if (![anAlbum.title isEqualToString:@".AppleDouble"]) {
                                if (self.iteration == -1) {
                                    // Add the album to the allAlbums table
                                    [databaseS insertAlbum:anAlbum intoTable:@"allAlbumsTemp" inDatabaseQueue:databaseS.allAlbumsDbQueue];
                                    self.tempAlbumsCount++;
                                    self.totalAlbumsProcessed++;
                                    
                                    if (self.tempAlbumsCount == WRITE_BUFFER_AMOUNT) {
                                        // Flush the records to disk
                                        [databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
                                             [db executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
                                             [db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
                                             [db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
                                         }];
                                        self.tempAlbumsCount = 0;
                                    }
                                } else {
                                    //Add album object to the subalbums table to be processed in the next iteration
                                    [databaseS insertAlbum:anAlbum intoTable:[NSString stringWithFormat:@"subalbums%ld", (long)(self.iteration + 1)] inDatabaseQueue:databaseS.allAlbumsDbQueue];
                                }
                            }
                            
                            // Update the loading screen message
                            if (self.iteration == -1) {
                                [self sendAlbumNotification:anAlbum.title];
                            }
                        } else {
                            // Initialize the Song
                            ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:child];
                            
                            // Add song object to the allSongs and genre databases
                            if (![aSong.title isEqualToString:@".AppleDouble"]) {
                                // Process it if it has a path
                                if (aSong.path) {
                                    // Add the song to the allSongs table
                                    [aSong insertIntoTable:@"allSongsTemp" inDatabaseQueue:databaseS.allSongsDbQueue];
                                    self.tempSongsCount++;
                                    self.totalSongsProcessed++;
                                    
                                    if (self.tempSongsCount == WRITE_BUFFER_AMOUNT) {
                                        // Flush the records to disk
                                        [databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
                                             [db executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
                                             [db executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
                                             NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [ISMSSong standardSongColumnSchema]];
                                             [db executeUpdate:query];
                                         }];
                                        self.tempSongsCount = 0;
                                    }
                                    
                                    // If it has a genre, process that
                                    if (aSong.genre) {
                                        [databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
                                             // Add the genre to the genre table
                                             [db executeUpdate:@"INSERT INTO genresTemp (genre) VALUES (?)", aSong.genre];
                                             self.tempGenresCount++;
                                             
                                             if (self.tempGenresCount == WRITE_BUFFER_AMOUNT) {
                                                 // Flush the records to disk
                                                 [db executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
                                                 //[databaseS.genresDb executeUpdate:@"DELETE * FROM genresTemp"];
                                                 [db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
                                                 [db executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
                                                 self.tempGenresCount = 0;
                                             }
                                             
                                             // Insert the song to the genresSongs table
                                             [aSong insertIntoGenreTable:@"genresSongsTemp" inDatabase:db];
                                             
                                             // Insert the song into the genresLayout table
                                             NSArray *splitPath = [aSong.path componentsSeparatedByString:@"/"];
                                             if ([splitPath count] <= 9) {
                                                 NSMutableArray *segments = [[NSMutableArray alloc] initWithArray:splitPath];
                                                 while ([segments count] < 9) {
                                                     [segments addObject:@""];
                                                 }
                                                 
                                                 NSString *query = @"INSERT INTO genresLayoutTemp (md5, genre, segs, seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                                                 [db executeUpdate:query, [aSong.path md5], aSong.genre, @([splitPath count]), [segments objectAtIndexSafe:0], [segments objectAtIndexSafe:1], [segments objectAtIndexSafe:2], [segments objectAtIndexSafe:3], [segments objectAtIndexSafe:4], [segments objectAtIndexSafe:5], [segments objectAtIndexSafe:6], [segments objectAtIndexSafe:7], [segments objectAtIndexSafe:8]];
                                                 self.tempGenresLayoutCount++;
                                                 
                                                 if (self.tempGenresLayoutCount == WRITE_BUFFER_AMOUNT) {
                                                     // Flush songs
                                                     [db executeUpdate:@"INSERT OR IGNORE INTO genresSongs SELECT * FROM genresSongsTemp"];
                                                     [db executeUpdate:@"DROP TABLE IF EXISTS genresSongsTemp"];
                                                     [db executeUpdate:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE genresSongsTemp (md5 TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
                                                     
                                                     // Flush the records to disk
                                                     [db executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
                                                     //[databaseS.genresDb executeUpdate:@"DELETE * FROM genresLayoutTemp"];
                                                     [db executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
                                                     [db executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
                                                     self.tempGenresLayoutCount = 0;
                                                 }
                                             }
                                         }];
                                    }
                                }
                            }
                            
                            // Update the loading screen message
                            if (self.iteration != -1) {
                                [self sendSongNotification:aSong.title];
                            }
                        }
                    }
                }];
            }
        }
		
		// Close the connection
		//
		self.receivedData = nil;
		
		// Handle the iteration
		//
		self.currentRow++;
		//DLog(@"currentRow: %i", currentRow);
		
		if (self.iteration == -1) {
			// Processing artist folders
			if (self.currentRow == self.artistCount) {
				// Done loading artist folders
				self.currentRow = 1;
				self.iteration++;
				[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"DROP TABLE resumeLoad"];
					
					// Flush the records to disk
					[db executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
				}];
				self.tempAlbumsCount = 0;
				
				// Flush the records to disk
				[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
					NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [ISMSSong standardSongColumnSchema]];
					[db executeUpdate:query];
				}];
				self.tempSongsCount = 0;
				
				[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
					// Flush the records to disk
					[db executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
					self.tempGenresCount = 0;
                    
                    // Flush songs
                    [db executeUpdate:@"INSERT OR IGNORE INTO genresSongs SELECT * FROM genresSongsTemp"];
                    [db executeUpdate:@"DROP TABLE IF EXISTS genresSongsTemp"];
                    [db executeUpdate:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE genresSongsTemp (md5 TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
					
					// Flush the records to disk
					[db executeUpdate:@"INSERT OR IGNORE INTO genresLayout SELECT * FROM genresLayoutTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
					self.tempGenresLayoutCount = 0;
				}];
				
				[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
					NSUInteger count = [db intForQuery:@"SELECT COUNT(*) FROM allAlbumsUnsorted"];
					[db executeUpdate:@"INSERT INTO allAlbumsUnsortedCount VALUES (?)", @(count)];
				}];
								
				[self startLoad];
			} else {
				[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"UPDATE resumeLoad SET artistNum = ?", @(self.currentRow)];
				}];
				 
				// Load the next folder
				//
				if (self.iteration < 4) {
					[self loadAlbumFolder];
				} else if (self.iteration == 4) {
					[self loadSort];
				}
			}
		} else {
			// Processing album folders
			if (self.currentRow == self.albumCount) {
				// This iteration is done
				self.currentRow = 0;
				self.iteration++;
				[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"UPDATE resumeLoad SET albumNum = ?, iteration = ?", @0, @(self.iteration)];
				}];
				
				// Flush the records to disk
				[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"INSERT INTO allAlbumsUnsorted SELECT * FROM allAlbumsTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsTemp(title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
				}];
				self.tempAlbumsCount = 0;
				
				// Flush the records to disk
				[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"INSERT INTO allSongsUnsorted SELECT * FROM allSongsTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS allSongsTemp"];
					NSString *query = [NSString stringWithFormat:@"CREATE TEMPORARY TABLE allSongsTemp (%@)", [ISMSSong standardSongColumnSchema]];
					[db executeUpdate:query];
				}];
				self.tempSongsCount = 0;
				
				// Flush the records to disk
				[databaseS.genresDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"INSERT OR IGNORE INTO genresUnsorted SELECT * FROM genresTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE genresTemp (genre TEXT)"];
                    
                    [db executeUpdate:@"INSERT OR IGNORE INTO genresSongs SELECT * FROM genresSongsTemp"];
                    [db executeUpdate:@"DROP TABLE IF EXISTS genresSongsTemp"];
                    [db executeUpdate:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE genresSongsTemp (md5 TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
					
					[db executeUpdate:@"INSERT INTO genresLayout SELECT * FROM genresLayoutTemp"];
					[db executeUpdate:@"DROP TABLE IF EXISTS genresLayoutTemp"];
					[db executeUpdate:@"CREATE TEMPORARY TABLE genresLayoutTemp (md5 TEXT, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
				}];
				
				self.tempGenresCount = 0;
				self.tempGenresLayoutCount = 0;
				
				[self startLoad];
			} else {
				[databaseS.allSongsDbQueue inDatabase:^(FMDatabase *db) {
					[db executeUpdate:@"UPDATE resumeLoad SET albumNum = ?", @(self.currentRow)];
				}];
            
				// Load the next folder
				//
				if (self.iteration < 4) {
					[self loadAlbumFolder];
				} else if (self.iteration == 4) {
                    //DLog(@"calling loadSort");
					[self loadSort];
				}
			}
		}
	
	}
}

@end
