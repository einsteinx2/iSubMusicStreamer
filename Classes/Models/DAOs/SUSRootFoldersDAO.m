//
//  SUSRootFoldersDAO.m
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersDAO.h"
#import "SUSRootFoldersLoader.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@interface SUSRootFoldersDAO() {
    NSInteger _selectedFolderId;
}
@end

@implementation SUSRootFoldersDAO

#pragma mark Lifecycle

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)delegate {
    if ((self = [super init])) {
		_delegate = delegate;
        _selectedFolderId = -1;
    }    
    return self;
}

- (void)dealloc {
	[_loader cancelLoad];
	_loader.delegate = nil;
}

#pragma mark Properties

+ (FMDatabaseQueue *)dbQueue {
    return databaseS.serverDbQueue;
}

- (FMDatabaseQueue *)dbQueue {
    return databaseS.serverDbQueue; 
}

- (NSString *)tableModifier {
	NSString *tableModifier = @"_all";
	if (self.selectedFolderId != -1) {
		tableModifier = [NSString stringWithFormat:@"_%ld", (long)self.selectedFolderId];
	}
	return tableModifier;
}

#pragma mark Private Methods

- (BOOL)addRootFolderToCache:(NSString*)folderId name:(NSString*)name {
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
		[db executeUpdate:query, folderId, [name cleanString]];
		hadError = [db hadError];
	}];
	return !hadError;
}

- (NSUInteger)rootFolderCount {
    NSString *table = [NSString stringWithFormat:@"rootFolderCount%@", self.tableModifier];
    if (![self.dbQueue tableExists:table]) return 0;
    
	NSString *query = [NSString stringWithFormat:@"SELECT count FROM %@ LIMIT 1", table];
	return [self.dbQueue intForQuery:query];
}

- (NSUInteger)rootFolderSearchCount {
	NSString *query = @"SELECT count(*) FROM rootFolderNameSearch";
	return [self.dbQueue intForQuery:query];
}

- (NSArray *)rootFolderIndexNames {
    NSString *table = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
    if (![self.dbQueue tableExists:table]) return [[NSArray alloc] init];
    
	__block NSMutableArray *names = [NSMutableArray arrayWithCapacity:0];
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", table];
		FMResultSet *result = [db executeQuery:query];
		while ([result next]) {
			NSString *name = [result stringForColumn:@"name"];
			[names addObject:name];
		}
		[result close];
	}];
	return [NSArray arrayWithArray:names];
}

- (NSArray *)rootFolderIndexPositions {
    NSString *table = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
    if (![self.dbQueue tableExists:table]) return [[NSArray alloc] init];
    
	__block NSMutableArray *positions = [NSMutableArray arrayWithCapacity:0];
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = [NSString stringWithFormat:@"SELECT position FROM %@", table];
		FMResultSet *result = [db executeQuery:query];
		while ([result next]) {
			@autoreleasepool {
				NSNumber *position = @([result intForColumn:@"position"]);
				[positions addObject:position];
			}
		}
		[result close];
	}];
    return positions.count == 0 ? nil : positions;
}

- (NSArray *)rootFolderIndexCounts {
    NSString *table = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
    if (![self.dbQueue tableExists:table]) return [[NSArray alloc] init];
    
	__block NSMutableArray *counts = [NSMutableArray arrayWithCapacity:0];
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = [NSString stringWithFormat:@"SELECT count FROM %@", table];
		FMResultSet *result = [db executeQuery:query];
		while ([result next]) {
			@autoreleasepool {
				NSNumber *folderCount = @([result intForColumn:@"count"]);
				[counts addObject:folderCount];
			}
		}
		[result close];
	}];
    return counts.count == 0 ? nil : counts;
}

- (ISMSFolderArtist *)rootFolderArtistForPosition:(NSUInteger)position {
	__block ISMSFolderArtist *folderArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = [NSString stringWithFormat:@"SELECT name, id FROM rootFolderNameCache%@ WHERE ROWID = ?", self.tableModifier];
		FMResultSet *result = [db executeQuery:query, @(position)];
		while ([result next]) {
			@autoreleasepool {
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
                folderArtist = [[ISMSFolderArtist alloc] initWithId:folderId name:name];
			}
		}
		[result close];
	}];
	return folderArtist;
}

- (ISMSFolderArtist *)rootFolderArtistForPositionInSearch:(NSUInteger)position {
	__block ISMSFolderArtist *folderArtist = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		NSString *query = @"SELECT name, id FROM rootFolderNameSearch WHERE ROWID = ?";
		FMResultSet *result = [db executeQuery:query, @(position)];
		while ([result next]) {
			@autoreleasepool  {
				NSString *name = [result stringForColumn:@"name"];
				NSString *folderId = [result stringForColumn:@"id"];
                folderArtist = [[ISMSFolderArtist alloc] initWithId:folderId name:name];
			}
		}
		[result close];
	}];
	
	return folderArtist;
}

- (void)rootFolderClearSearch {
	[self.dbQueue inDatabase:^(FMDatabase *db) {
        if ([db tableExists:@"rootFolderNameSearch"]) {
            [db executeUpdate:@"DELETE FROM rootFolderNameSearch"];
        } else {
            // Inialize the search DB
            NSString *query = @"DROP TABLE IF EXISTS rootFolderNameSearch";
            [db executeUpdate:query];
            query = @"CREATE TEMPORARY TABLE rootFolderNameSearch (id TEXT PRIMARY KEY, name TEXT)";
            [db executeUpdate:query];
        }
	}];
}

- (void)rootFolderPerformSearch:(NSString *)name {
	[self.dbQueue inDatabase:^(FMDatabase *db) {
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

- (BOOL)rootFolderIsFolderCached {
	NSString *query = [NSString stringWithFormat:@"rootFolderIndexCache%@", self.tableModifier];
	return [self.dbQueue tableExists:query];
}

#pragma mark Public DAO Methods

- (NSInteger)selectedFolderId {
    return _selectedFolderId;
}

- (void)setSelectedFolderId:(NSInteger)selectedFolderId {
    _selectedFolderId = selectedFolderId;
    _indexNames = nil;
    _indexCounts = nil;
    _indexPositions = nil;
}

- (BOOL)isRootFolderIdCached {
	return [self rootFolderIsFolderCached];
}

- (NSUInteger)count {
	return [self rootFolderCount];
}

- (NSUInteger)searchCount {
	return [self rootFolderSearchCount];
}

- (NSArray *)indexNames {
	if (!_indexNames || _indexNames.count == 0) {
		_indexNames = [self rootFolderIndexNames];
	}
	return _indexNames;
}

- (NSArray *)indexPositions {
	if (!_indexPositions || _indexPositions.count == 0) {
		_indexPositions = [self rootFolderIndexPositions];
	}
	return _indexPositions;
}

- (NSArray *)indexCounts {
	if (!_indexCounts) {
		_indexCounts = [self rootFolderIndexCounts];
    }
	return _indexCounts;
}

- (ISMSFolderArtist *)folderArtistForPosition:(NSUInteger)position {
	return [self rootFolderArtistForPosition:position];
}

- (ISMSFolderArtist *)folderArtistForPositionInSearch:(NSUInteger)position {
	return [self rootFolderArtistForPositionInSearch:position];
}

- (void)clearSearchTable {
	[self rootFolderClearSearch];
}

- (void)searchForFolderName:(NSString *)name {
	[self rootFolderPerformSearch:name];
}

#pragma mark Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSRootFoldersLoader alloc] initWithDelegate:self];
    self.loader.selectedFolderId = self.selectedFolderId;
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
		
	_indexNames = nil;
	_indexPositions = nil;
	_indexCounts = nil;
	
	// Force all subfolders to reload
    [databaseS resetFolderCache];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
		[self.delegate loadingFinished:nil];
	}
}

@end
