//
//  ISMSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSRootFoldersLoader.h"

@implementation ISMSRootFoldersLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_RootFolders;
}

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
    return [[SUSRootFoldersLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSRootFoldersLoader alloc] initWithCallbackBlock:theBlock];
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

#pragma mark - Database Methods

- (void)resetRootFolderTempTable
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 [db executeUpdate:@"DROP TABLE IF EXISTS rootFolderNameCacheTemp"];
		 [db executeUpdate:@"CREATE TEMPORARY TABLE rootFolderNameCacheTemp (id TEXT, name TEXT)"];
	 }];
	
	self.tempRecordCount = 0;
}

- (BOOL)clearRootFolderTempTable
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 [db executeUpdate:@"DELETE FROM rootFolderNameCacheTemp"];
		 hadError = [db hadError];
	 }];
	return !hadError;
}

- (NSUInteger)rootFolderUpdateCount
{
	__block NSNumber *folderCount = nil;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 NSString *query = [NSString stringWithFormat:@"DELETE FROM rootFolderCount%@", self.tableModifier];
		 [db executeUpdate:query];
		 
		 query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM rootFolderNameCache%@", self.tableModifier];
		 folderCount = @([db intForQuery:query]);
		 
		 query = [NSString stringWithFormat:@"INSERT INTO rootFolderCount%@ VALUES (?)", self.tableModifier];
		 [db executeUpdate:query, folderCount];
		 
	 }];
	return [folderCount intValue];
}

- (BOOL)moveRootFolderTempTableRecordsToMainCache
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 //DLog(@"tableModifier: %@", self.tableModifier);
		 NSString *query = @"INSERT INTO rootFolderNameCache%@ SELECT * FROM rootFolderNameCacheTemp";
		 [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
		 hadError = [db hadError];
	 }];
	
	return !hadError;
}

- (void)resetRootFolderCache
{    
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 // Delete the old tables
		 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderIndexCache%@", self.tableModifier]];
		 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderNameCache%@", self.tableModifier]];
		 [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderCount%@", self.tableModifier]];
		 //[self.db executeUpdate:@"VACUUM"]; // Removed because it takes waaaaaay too long, maybe make a button in settings?
		 
		 // Create the new tables
		 NSString *query;
		 query = @"CREATE TABLE rootFolderIndexCache%@ (name TEXT PRIMARY KEY, position INTEGER, count INTEGER)";
		 [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
		 query = @"CREATE VIRTUAL TABLE rootFolderNameCache%@ USING FTS3 (id TEXT PRIMARY KEY, name TEXT, tokenize=porter)";
		 [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
		 query = @"CREATE INDEX name ON rootFolderNameCache%@ (name ASC)";
		 [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
		 query = @"CREATE TABLE rootFolderCount%@ (count INTEGER)";
		 [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
	 }];
}

- (BOOL)addRootFolderIndexToCache:(NSUInteger)position count:(NSUInteger)folderCount name:(NSString*)name
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderIndexCache%@ VALUES (?, ?, ?)", self.tableModifier];
		 [db executeUpdate:query, name, @(position), @(folderCount)];
		 hadError = [db hadError];
	 }];
	return !hadError;
}

- (BOOL)addRootFolderToTempCache:(NSString*)folderId name:(NSString*)name
{
	__block BOOL hadError = NO;
	// Add the shortcut to the DB
	if (folderId != nil && name != nil)
	{
		[self.dbQueue inDatabase:^(FMDatabase *db)
		 {
			 NSString *query = @"INSERT INTO rootFolderNameCacheTemp VALUES (?, ?)";
			 [db executeUpdate:query, folderId, name];
			 hadError = [db hadError];
			 self.tempRecordCount++;
		 }];
	}
	
	// Flush temp records to main cache if necessary
	if (self.tempRecordCount == TEMP_FLUSH_AMOUNT)
	{
		if (![self moveRootFolderTempTableRecordsToMainCache])
			hadError = YES;
		
		[self resetRootFolderTempTable];
		
		self.tempRecordCount = 0;
	}
    
	return !hadError;
}

- (BOOL)addRootFolderToMainCache:(NSString*)folderId name:(NSString*)name
{
	__block BOOL hadError = NO;
	// Add the shortcut to the DB
	if (folderId != nil && name != nil)
	{
		[self.dbQueue inDatabase:^(FMDatabase *db)
		 {
			 NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
			 [db executeUpdate:query, folderId, name];
			 hadError = [db hadError];
		 }];
	}
    
	return !hadError;
}

@end
