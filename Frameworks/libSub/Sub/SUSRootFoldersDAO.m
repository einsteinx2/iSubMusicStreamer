//
//  SUSRootFoldersDAO.m
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersDAO.h"
#import "ISMSRootFoldersLoader.h"

@interface SUSRootFoldersDAO ()
{
    __strong NSNumber *_selectedFolderId;
}
@end

@implementation SUSRootFoldersDAO

#pragma mark - Lifecycle

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
    if ((self = [super init]))
	{
		_delegate = theDelegate;
    }    
    return self;
}

- (void)dealloc
{
	[_loader cancelLoad];
	_loader.delegate = nil;
}

#pragma mark - Properties

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue; 
}

- (NSString *)tableModifier
{
	NSString *tableModifier = @"_all";
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
		tableModifier = [NSString stringWithFormat:@"_%@", [self.selectedFolderId stringValue]];
	}
	return tableModifier;
}

#pragma mark - Private Methods

- (BOOL)addRootFolderToCache:(NSString*)folderId name:(NSString*)name
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
		[db executeUpdate:query, folderId, [name cleanString]];
		hadError = [db hadError];
	}];
	return !hadError;
}

- (NSUInteger)rootFolderCount
{
	NSString *query = [NSString stringWithFormat:@"SELECT count FROM rootFolderCount%@ LIMIT 1", self.tableModifier];
	return [self.dbQueue intForQuery:query];
}

- (NSUInteger)rootFolderSearchCount
{
	NSString *query = @"SELECT count(*) FROM rootFolderNameSearch";
	return [self.dbQueue intForQuery:query];
}

- (NSArray *)rootFolderIndexNames
{
	__block NSMutableArray *names = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			NSString *name = [result stringForColumn:@"name"];
			[names addObject:name];
		}
		[result close];
	}];
	
	return [NSArray arrayWithArray:names];
}

- (NSArray *)rootFolderIndexPositions
{	
	__block NSMutableArray *positions = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *position = @([result intForColumn:@"position"]);
				[positions addObject:position];
			}
		}
		[result close];
	}];
		
	if (positions.count == 0)
		return nil;
	else
		return [NSArray arrayWithArray:positions];
}

- (NSArray *)rootFolderIndexCounts
{	
	__block NSMutableArray *counts = [NSMutableArray arrayWithCapacity:0];
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderIndexCache%@", self.tableModifier];
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *folderCount = @([result intForColumn:@"count"]);
				[counts addObject:folderCount];
			}
		}
		[result close];
	}];
		
	if (counts.count == 0)
		return nil;
	else
		return [NSArray arrayWithArray:counts];
}

- (ISMSArtist *)rootFolderArtistForPosition:(NSUInteger)position
{
	__block ISMSArtist *anArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootFolderNameCache%@ WHERE ROWID = ?", self.tableModifier];
		FMResultSet *result = [db executeQuery:query, @(position)];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
				anArtist = [ISMSArtist artistWithName:name andArtistId:folderId];
			}
		}
		[result close];
	}];
	
	return anArtist;
}

- (ISMSArtist *)rootFolderArtistForPositionInSearch:(NSUInteger)position
{
	__block ISMSArtist *anArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		NSString *query = @"SELECT * FROM rootFolderNameSearch WHERE ROWID = ?";
		FMResultSet *result = [db executeQuery:query, @(position)];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
				anArtist = [ISMSArtist artistWithName:name andArtistId:folderId];
			}
		}
		[result close];
	}];
	
	return anArtist;
}

- (void)rootFolderClearSearch
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DELETE FROM rootFolderNameSearch"];
	}];
}

- (void)rootFolderPerformSearch:(NSString *)name
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		// Inialize the search DB
		NSString *query = @"DROP TABLE IF EXISTS rootFolderNameSearch";
		[db executeUpdate:query];
		query = @"CREATE TEMPORARY TABLE rootFolderNameSearch (id TEXT PRIMARY KEY, name TEXT)";
		[db executeUpdate:query];
		
		// Perform the search
		query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameSearch SELECT * FROM rootFolderNameCache%@ WHERE name LIKE ? LIMIT 100", self.tableModifier];
		[db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
		if ([db hadError]) {
		//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
	}];
}

- (BOOL)rootFolderIsFolderCached
{
	NSString *query = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
	return [self.dbQueue tableExists:query];
}

#pragma mark - Public DAO Methods

+ (void)setFolderDropdownFolders:(NSDictionary *)folders
{
	[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS rootFolderDropdownCache"];
		[db executeUpdate:@"CREATE TABLE rootFolderDropdownCache (id INTEGER, name TEXT)"];
		
		for (NSNumber *folderId in [folders allKeys])
		{
			NSString *folderName = [folders objectForKey:folderId];
			[db executeUpdate:@"INSERT INTO rootFolderDropdownCache VALUES (?, ?)", folderId, folderName];
		}
	}];
}

+ (NSDictionary *)folderDropdownFolders
{
	if (![databaseS.albumListCacheDbQueue tableExists:@"rootFolderDropdownCache"])
		return nil;
	
	__block NSMutableDictionary *folders = [NSMutableDictionary dictionaryWithCapacity:0];

	[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM rootFolderDropdownCache"];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSNumber *folderId = @([result intForColumn:@"id"]);
				NSString *folderName = [result stringForColumn:@"name"];
				[folders setObject:folderName forKey:folderId];
			}
		}
		[result close];
	}];
	
	return [NSDictionary dictionaryWithDictionary:folders];
}

- (NSNumber *)selectedFolderId
{
	@synchronized(self)
	{
		if (_selectedFolderId == nil)
			return @(-1);
		else
			return _selectedFolderId;
	}
}

- (void)setSelectedFolderId:(NSNumber *)selectedFolderId
{
	@synchronized(self)
	{
		_selectedFolderId = selectedFolderId;
		_indexNames = nil;
		_indexCounts = nil;
		_indexPositions = nil;
	}
}

- (BOOL)isRootFolderIdCached
{
	return [self rootFolderIsFolderCached];
}

- (NSUInteger)count
{
	return [self rootFolderCount];
}

- (NSUInteger)searchCount
{
	return [self rootFolderSearchCount];
}

- (NSArray *)indexNames
{
	if (_indexNames == nil || _indexNames.count == 0)
	{
		_indexNames = [self rootFolderIndexNames];
	}
	
	return _indexNames;
}

- (NSArray *)indexPositions
{
	if (_indexPositions == nil || _indexPositions.count == 0)
	{
		_indexPositions = [self rootFolderIndexPositions];
	}
	return _indexPositions;
}

- (NSArray *)indexCounts
{
	if (_indexCounts == nil)
	{
		_indexCounts = [self rootFolderIndexCounts];
	}
	
	return _indexCounts;
}

- (ISMSArtist *)artistForPosition:(NSUInteger)position
{
	return [self rootFolderArtistForPosition:position];
}

- (ISMSArtist *)artistForPositionInSearch:(NSUInteger)position
{
	return [self rootFolderArtistForPositionInSearch:position];
}

- (void)clearSearchTable
{
	[self rootFolderClearSearch];
}

- (void)searchForFolderName:(NSString *)name
{
	[self rootFolderPerformSearch:name];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{
    if ([settingsS.serverType isEqualToString:WAVEBOX])
    {
        WBDatabaseUpdateLoader *dbUpdate = [[WBDatabaseUpdateLoader alloc] initWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
        {
            WBDatabaseUpdateLoader *theLoader = (WBDatabaseUpdateLoader *)loader;
            
            if (success && theLoader.requestYieldedNewQueries)
            {
                self.loader = [ISMSRootFoldersLoader loaderWithDelegate:self];
                self.loader.selectedFolderId = self.selectedFolderId;
                [self.loader startLoad];
            }
            else
            {
                if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
                {
                    [self.delegate loadingFinished:nil];
                    return;
                }
            }
        }];
        [dbUpdate startLoad];
    }
         
    else
    {
        self.loader = [ISMSRootFoldersLoader loaderWithDelegate:self];
        self.loader.selectedFolderId = self.selectedFolderId;
        [self.loader startLoad];
    }

}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
		
	_indexNames = nil;
	_indexPositions = nil;
	_indexCounts = nil;
	
	// Force all subfolders to reload
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS albumListCache"];
		[db executeUpdate:@"DROP TABLE IF EXISTS albumsCache"];
		[db executeUpdate:@"DROP TABLE IF EXISTS albumsCacheCount"];
		[db executeUpdate:@"DROP TABLE IF EXISTS songsCacheCount"];
		[db executeUpdate:@"DROP TABLE IF EXISTS folderLength"];
		[db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
		[db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
		[db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
		[db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
		[db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
		[db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
		[db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
	}];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
