//
//  SUSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "EX2Kit.h"

#define TEMP_FLUSH_AMOUNT 400

@implementation SUSRootFoldersLoader

- (SUSLoaderType)type
{
    return SUSLoaderType_RootFolders;
}

#pragma mark Data loading

- (NSURLRequest *)createRequest {
    NSDictionary *parameters = nil;
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        parameters = @{@"musicFolderId": n2N([self.selectedFolderId stringValue])};
	}
    
    return [NSMutableURLRequest requestWithSUSAction:@"getIndexes" parameters:parameters];
}

- (void)processResponse {
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
	
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
            __block NSUInteger rowCount = 0;
            __block NSUInteger sectionCount = 0;
            __block NSUInteger rowIndex = 0;
            
            [root iterate:@"indexes.shortcut" usingBlock:^(RXMLElement *e) {
                rowIndex = 1;
                rowCount++;
                sectionCount++;
                
                // Parse the shortcut
                NSString *folderId = [e attribute:@"id"];
                NSString *name = [[e attribute:@"name"] cleanString];
                
                // Add the record to the cache
                [self addRootFolderToTempCache:folderId name:name];
            }];
            
            if (rowIndex > 0) {
                [self addRootFolderIndexToCache:rowIndex count:sectionCount name:@"★"];
                //DLog(@"Adding shortcut to index table, count %i", sectionCount);
            }
            
            [root iterate:@"indexes.index" usingBlock:^(RXMLElement *e) {
                NSTimeInterval dbInserts = 0;
                sectionCount = 0;
                rowIndex = rowCount + 1;
                
                for (RXMLElement *artist in [e children:@"artist"]) {
                    rowCount++;
                    sectionCount++;
                    
                    // Create the artist object and add it to the
                    // array for this section if not named .AppleDouble
                    if (![[artist attribute:@"name"] isEqualToString:@".AppleDouble"]) {
                        // Parse the top level folder
                        NSString *folderId = [artist attribute:@"id"];
                        NSString *name = [[artist attribute:@"name"] cleanString];
                        
                        // Add the folder to the DB
                        NSDate *startTime3 = [NSDate date];
                        [self addRootFolderToTempCache:folderId name:name];
                        dbInserts += [[NSDate date] timeIntervalSinceDate:startTime3];
                    }
                }
                
                NSString *indexName = [[e attribute:@"name"] cleanString];
                [self addRootFolderIndexToCache:rowIndex count:sectionCount name:indexName];
            }];
            
            // Move any remaining temp records to main cache
            [self moveRootFolderTempTableRecordsToMainCache];
            [self resetRootFolderTempTable];
            
            // Update the count
            [self rootFolderUpdateCount];
            
            // Save the reload time
            [settingsS setRootFoldersReloadTime:[NSDate date]];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
	}
}

#pragma mark - Database Methods

- (FMDatabaseQueue *)dbQueue {
    return databaseS.albumListCacheDbQueue;
}

- (NSString *)tableModifier {
    NSString *tableModifier = @"_all";
    
    if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        tableModifier = [NSString stringWithFormat:@"_%@", [self.selectedFolderId stringValue]];
    }
    
    return tableModifier;
}

- (void)resetRootFolderTempTable {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         [db executeUpdate:@"DROP TABLE IF EXISTS rootFolderNameCacheTemp"];
         [db executeUpdate:@"CREATE TEMPORARY TABLE rootFolderNameCacheTemp (id TEXT, name TEXT)"];
     }];
    
    self.tempRecordCount = 0;
}

- (BOOL)clearRootFolderTempTable {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         [db executeUpdate:@"DELETE FROM rootFolderNameCacheTemp"];
         hadError = [db hadError];
     }];
    return !hadError;
}

- (NSUInteger)rootFolderUpdateCount {
    __block NSNumber *folderCount = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"DELETE FROM rootFolderCount%@", self.tableModifier];
         [db executeUpdate:query];
         
         query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM rootFolderNameCache%@", self.tableModifier];
         folderCount = @([db intForQuery:query]);
         
         query = [NSString stringWithFormat:@"INSERT INTO rootFolderCount%@ VALUES (?)", self.tableModifier];
         [db executeUpdate:query, folderCount];
         
     }];
    return [folderCount intValue];
}

- (BOOL)moveRootFolderTempTableRecordsToMainCache {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = @"INSERT INTO rootFolderNameCache%@ SELECT * FROM rootFolderNameCacheTemp";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
         hadError = [db hadError];
     }];
    
    return !hadError;
}

- (void)resetRootFolderCache {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         // Delete the old tables
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderIndexCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderNameCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootFolderCount%@", self.tableModifier]];
         
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

- (BOOL)addRootFolderIndexToCache:(NSUInteger)position count:(NSUInteger)folderCount name:(NSString*)name {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderIndexCache%@ VALUES (?, ?, ?)", self.tableModifier];
         [db executeUpdate:query, name, @(position), @(folderCount)];
         hadError = [db hadError];
     }];
    return !hadError;
}

- (BOOL)addRootFolderToTempCache:(NSString*)folderId name:(NSString*)name {
    __block BOOL hadError = NO;
    // Add the shortcut to the DB
    if (folderId != nil && name != nil) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
             NSString *query = @"INSERT INTO rootFolderNameCacheTemp VALUES (?, ?)";
             [db executeUpdate:query, folderId, name];
             hadError = [db hadError];
             self.tempRecordCount++;
         }];
    }
    
    // Flush temp records to main cache if necessary
    if (self.tempRecordCount == TEMP_FLUSH_AMOUNT) {
        if (![self moveRootFolderTempTableRecordsToMainCache]) {
            hadError = YES;
        }
        
        [self resetRootFolderTempTable];
        
        self.tempRecordCount = 0;
    }
    
    return !hadError;
}

- (BOOL)addRootFolderToMainCache:(NSString*)folderId name:(NSString*)name {
    __block BOOL hadError = NO;
    // Add the shortcut to the DB
    if (folderId != nil && name != nil) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
             NSString *query = [NSString stringWithFormat:@"INSERT INTO rootFolderNameCache%@ VALUES (?, ?)", self.tableModifier];
             [db executeUpdate:query, folderId, name];
             hadError = [db hadError];
         }];
    }
    
    return !hadError;
}

@end
