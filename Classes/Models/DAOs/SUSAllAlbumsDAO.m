//
//  SUSAllAlbumsDAO.m
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSAllAlbumsDAO.h"
#import "SUSAllSongsLoader.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "ISMSIndex.h"
#import "Defines.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation SUSAllAlbumsDAO

- (FMDatabaseQueue *)dbQueue {
    return databaseS.allAlbumsDbQueue; 
}

#pragma mark - Private Methods

- (NSUInteger)allAlbumsCount {
	NSUInteger value = 0;
	if ([self.dbQueue tableExists:@"allAlbumsCount"] && [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0) {
		value = [self.dbQueue intForQuery:@"SELECT count FROM allAlbumsCount LIMIT 1"];
	}
	return value;
}

- (NSUInteger)allAlbumsSearchCount {
	__block NSUInteger value;
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"CREATE TEMPORARY TABLE IF NOT EXISTS allAlbumsNameSearch (rowIdInAllAlbums INTEGER)"];
		value = [db intForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"];
        //DLog(@"allAlbumsNameSearch count: %i   value: %i", [db intForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"], value);
	}];
	return value;
}

- (NSArray *)allAlbumsIndex {
	__block NSMutableArray *indexItems = [NSMutableArray arrayWithCapacity:0];
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:@"SELECT * FROM allAlbumsIndexCache"];
		while ([result next]) {
			@autoreleasepool  {
				ISMSIndex *item = [[ISMSIndex alloc] init];
				item.name = [result stringForColumn:@"name"];
				item.position = [result intForColumn:@"position"];
				item.count = [result intForColumn:@"count"];
				[indexItems addObject:item];
			}
		}
		[result close];
	}];
	return indexItems;
}

- (ISMSFolderAlbum *)allAlbumsFolderAlbumForPosition:(NSUInteger)position {
//	__block ISMSFolderAlbum *folderAlbum = nil;
//	[self.dbQueue inDatabase:^(FMDatabase *db) {
//        FMResultSet *result = [db executeQuery:@"SELECT * FROM allAlbums WHERE ROWID = ?", @(position)];
//		if ([result next]) {
//            folderAlbum = [[ISMSFolderAlbum alloc] initWithResult:result];
//		}
//		[result close];
//	}];
//	return folderAlbum;
    return nil;
}

- (ISMSFolderAlbum *)allAlbumsFolderAlbumForPositionInSearch:(NSUInteger)position {
	NSUInteger rowId = [self.dbQueue intForQuery:@"SELECT rowIdInAllAlbums FROM allAlbumsNameSearch WHERE ROWID = ?", @(position)];
	return [self allAlbumsFolderAlbumForPosition:rowId];
}

- (void)allAlbumsClearSearch {
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		[db executeUpdate:@"DELETE FROM allAlbumsNameSearch"];
	}];
}

- (void)allAlbumsPerformSearch:(NSString *)name {
	[self.dbQueue inDatabase:^(FMDatabase *db) {
		// Inialize the search DB
		[db executeUpdate:@"DROP TABLE IF EXISTS allAlbumsNameSearch"];
		[db executeUpdate:@"CREATE TEMPORARY TABLE allAlbumsNameSearch (rowIdInAllAlbums INTEGER)"];
		
		// Perform the search
		NSString *query = @"INSERT INTO allAlbumsNameSearch SELECT ROWID FROM allAlbums WHERE title LIKE ? LIMIT 100";
		[db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
		//if ([db hadError])
		//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
        DDLogVerbose(@"[SUSAllAlbumsDAO] allAlbumsNameSearch count: %i", [db intForQuery:@"SELECT count(*) FROM allAlbumsNameSearch"]);
	}];
}

- (BOOL)allAlbumsIsDataLoaded {
    return [self.dbQueue intForQuery:@"SELECT COUNT(*) FROM allAlbumsCount"] > 0;
}

#pragma mark - Public DAO Methods

- (NSUInteger)count {
	if ([SUSAllSongsLoader isLoading]) return 0;
    
	return [self allAlbumsCount];
}

- (NSUInteger)searchCount {
	return [self allAlbumsSearchCount];
}

- (NSArray *)index {
	if ([SUSAllSongsLoader isLoading]) return nil;
	
	if (index == nil) {
		index = [self allAlbumsIndex];
	}
	return index;
}

- (ISMSFolderAlbum *)folderAlbumForPosition:(NSUInteger)position {
	return [self allAlbumsFolderAlbumForPosition:position];
}

- (ISMSFolderAlbum *)folderAlbumForPositionInSearch:(NSUInteger)position {
	return [self allAlbumsFolderAlbumForPositionInSearch:position];
}

- (void)clearSearchTable {
	[self allAlbumsClearSearch];
}

- (void)searchForAlbumName:(NSString *)name {
	[self allAlbumsPerformSearch:name];
}

- (BOOL)isDataLoaded {
	return [self allAlbumsIsDataLoaded];
}

@end
