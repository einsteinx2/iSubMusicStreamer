//
//  SUSAllSongsDAO.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllSongsDAO.h"
#import "SUSAllSongsLoader.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "ISMSSong+DAO.h"
#import "ISMSIndex.h"
#import "EX2Kit.h"

@implementation SUSAllSongsDAO

- (instancetype)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate
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

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.allSongsDbQueue;
}

#pragma mark - Private Methods

- (NSUInteger)allSongsCount
{
	NSUInteger value = 0;
	
	if ([self.dbQueue tableExists:@"allSongsCount"] && [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM allSongsCount"] > 0)
	{
		value = [self.dbQueue intForQuery:@"SELECT count FROM allSongsCount LIMIT 1"];
	}
	
	return value;
}

- (NSUInteger)allSongsSearchCount
{
	NSUInteger value = [self.dbQueue intForQuery:@"SELECT count(*) FROM allSongsNameSearch"];
	
	return value;
}

- (NSArray *)allSongsIndex
{
	NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT * FROM allSongsIndexCache"];
		while ([result next])
		{
			ISMSIndex *item = [[ISMSIndex alloc] init];
			item.name = [result stringForColumn:@"name"];
			item.position = [result intForColumn:@"position"];
			item.count = [result intForColumn:@"count"];
			[indexItems addObject:item];
		}
		[result close];
	}];
	return [NSArray arrayWithArray:indexItems];
}

- (ISMSSong *)allSongsSongForPosition:(NSUInteger)position
{
	return [ISMSSong songFromDbRow:position-1 inTable:@"allSongs" inDatabaseQueue:self.dbQueue];
}

- (ISMSSong *)allSongsSongForPositionInSearch:(NSUInteger)position
{
	NSUInteger rowId = [self.dbQueue intForQuery:@"SELECT rowIdInAllSongs FROM allSongsNameSearch WHERE ROWID = ?", @(position)];
	return [self allSongsSongForPosition:rowId];
}

- (void)allSongsClearSearch
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DELETE FROM allSongsNameSearch"];
	}];	
}

- (void)allSongsPerformSearch:(NSString *)name
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		// Inialize the search DB
		[db executeUpdate:@"DROP TABLE IF EXISTS allSongsNameSearch"];
		[db executeUpdate:@"CREATE TEMPORARY TABLE allSongsNameSearch (rowIdInAllSongs INTEGER)"];
		
		// Perform the search
		NSString *query = @"INSERT INTO allSongsNameSearch SELECT ROWID FROM allSongs WHERE title LIKE ? LIMIT 100";
		[db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
		if ([db hadError])
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
}

- (BOOL)allSongsIsDataLoaded
{
	BOOL isLoaded = NO;
	
	if ([self.dbQueue tableExists:@"allSongsCount"] && [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM allSongsCount"] > 0)
	{
		isLoaded = YES;
	}
	
	return isLoaded;
}

#pragma mark - Public DAO Methods

- (NSUInteger)count
{
	if ([SUSAllSongsLoader isLoading])
		return 0;
	
	return [self allSongsCount];
}

- (NSUInteger)searchCount
{
	return [self allSongsSearchCount];
}

- (NSArray *)index
{
	if ([SUSAllSongsLoader isLoading])
		return nil;
	
	if (index == nil)
	{
		index = [self allSongsIndex];
	}
	
	return index;
}

- (ISMSSong *)songForPosition:(NSUInteger)position
{
	return [self allSongsSongForPosition:position];
}

- (ISMSSong *)songForPositionInSearch:(NSUInteger)position
{
	return [self allSongsSongForPositionInSearch:position];
}

- (void)clearSearchTable
{
	[self allSongsClearSearch];
}

- (void)searchForSongName:(NSString *)name
{
	[self allSongsPerformSearch:name];
}

- (BOOL)isDataLoaded
{
	return [self allSongsIsDataLoaded];
}

- (void)allSongsRestartLoad
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"CREATE TABLE restartLoad (a INTEGER)"];
	}];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
	if (![SUSAllSongsLoader isLoading])
	{
		[self allSongsRestartLoad];
		[self startLoad];
	}
}

- (void)startLoad
{
	if (![SUSAllSongsLoader isLoading])
	{
		index = nil;
		self.loader = [[SUSAllSongsLoader alloc] initWithDelegate:self.delegate];
		[self.loader startLoad];
	}
}

- (void)cancelLoad
{
	if ([SUSAllSongsLoader isLoading])
	{
		[self.loader cancelLoad];
		self.loader.delegate = nil;
        self.loader = nil;
	}
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{	
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader *)theLoader
{	
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
