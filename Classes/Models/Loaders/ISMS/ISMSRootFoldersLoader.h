//
//  ISMSRootFoldersLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

#define TEMP_FLUSH_AMOUNT 400

@class FMDatabase;

@interface ISMSRootFoldersLoader : ISMSLoader

@property NSUInteger tempRecordCount;
@property (strong) NSNumber *selectedFolderId;

- (NSString *)tableModifier;

// Database methods
- (FMDatabaseQueue *)dbQueue;
- (void)resetRootFolderTempTable;
- (BOOL)clearRootFolderTempTable;
- (NSUInteger)rootFolderUpdateCount;
- (BOOL)moveRootFolderTempTableRecordsToMainCache;
- (void)resetRootFolderCache;
- (BOOL)addRootFolderIndexToCache:(NSUInteger)position count:(NSUInteger)folderCount name:(NSString*)name;
- (BOOL)addRootFolderToMainCache:(NSString*)folderId name:(NSString*)name;
- (BOOL)addRootFolderToTempCache:(NSString*)folderId name:(NSString*)name;

@end

#import "SUSRootFoldersLoader.h"
