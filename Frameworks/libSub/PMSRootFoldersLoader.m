//
//  PMSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSRootFoldersLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation PMSRootFoldersLoader

#pragma mark Data loading

- (NSURLRequest *)createRequest
{
    NSString *action = @"folders";
    
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1)
	{
        return [NSMutableURLRequest requestWithPMSAction:action itemId:self.selectedFolderId.stringValue];
	}
    
    return [NSMutableURLRequest requestWithPMSAction:action];
}

- (void)startLoad
{
    // processResponse will take care of talking to the metadata db and getting the necessary information.
    [self processResponse];
}

- (void)processResponse
{			
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
    
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
    {
        FMResultSet *mediaFolders = [db executeQuery:@"SELECT * FROM folder WHERE parent_folder_id IS NULL"];
        while ([mediaFolders next])
        {
            NSString *folderId = [mediaFolders stringForColumn:@"folder_id"];
            FMResultSet *folderContents = [db executeQuery:@"SELECT folder_id, folder_name FROM folder WHERE parent_folder_id = ? ORDER BY folder_name ASC", folderId];
            while ([folderContents next])
            {
                NSString *fId = [folderContents stringForColumn:@"folder_id"];
                NSString *fName = [folderContents stringForColumn:@"folder_name"];
                
                [self addRootFolderToMainCache:fId name:fName];
            }
            [folderContents close];
        }
        [mediaFolders close];
    }];
    
    // Move any remaining temp records to main cache
    [self moveRootFolderTempTableRecordsToMainCache];
    [self resetRootFolderTempTable];
    
    // Update the count
	NSInteger totalCount = [self rootFolderUpdateCount];
    
	NSString *tableName = [NSString stringWithFormat:@"rootFolderNameCache%@", self.tableModifier];
	NSArray *indexes = [databaseS sectionInfoFromTable:tableName inDatabaseQueue:self.dbQueue withColumn:@"name"];
    DLog(@"indexes: %@", indexes);
	for (int i = 0; i < indexes.count; i++)
	{
		NSArray *index = [indexes objectAtIndex:i];
		NSArray *nextIndex = [indexes objectAtIndexSafe:i+1];
		
		NSString *name = [index objectAtIndex:0];
		NSInteger row = [[index objectAtIndex:1] intValue] + 1; // Add 1 to compensate for sqlite row numbering
		NSInteger count = nextIndex ? [[nextIndex objectAtIndex:1] intValue] - row + 1 : totalCount - row + 1; // TODO: WHY DO WE NEED TO ADD 1 HERE? TOO TIRED TO THINK ABOUT IT RIGHT NOW
        DLog(@"name: %@  row: %ld  count: %ld", name, (long)row, (long)count);
		[self addRootFolderIndexToCache:row count:count name:name];
	}
	
	// Save the reload time
	[settingsS setRootFoldersReloadTime:[NSDate date]];
    
    // Update the count
    [self rootFolderUpdateCount];
    
    // Notify the delegate that the loading is finished
    [self informDelegateLoadingFinished];
    
    // Clean up the connection
	self.connection = nil;
	self.receivedData = nil;
}

@end
