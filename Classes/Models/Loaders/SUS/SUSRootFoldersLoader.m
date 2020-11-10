//
//  SUSRootFoldersLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/28/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSRootFoldersLoader.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSRootFoldersLoader

#pragma mark Data loading

- (NSURLRequest *)createRequest
{
	//DLog(@"Starting load");
    NSDictionary *parameters = nil;
	if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        parameters = @{@"musicFolderId": n2N([self.selectedFolderId stringValue])};
	}
    
    return [NSMutableURLRequest requestWithSUSAction:@"getIndexes" parameters:parameters];
}

- (void)processResponse
{			
	// Clear the database
	[self resetRootFolderCache];
	
	// Create the temp table to store records
	[self resetRootFolderTempTable];
	
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    }
	else
	{
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
        }
        else
        {
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
            
            if (rowIndex > 0)
            {
                [self addRootFolderIndexToCache:rowIndex count:sectionCount name:@"★"];
                //DLog(@"Adding shortcut to index table, count %i", sectionCount);
            }
            
            [root iterate:@"indexes.index" usingBlock:^(RXMLElement *e) {
                NSTimeInterval dbInserts = 0;
                sectionCount = 0;
                rowIndex = rowCount + 1;
                
                for (RXMLElement *artist in [e children:@"artist"])
                {
                    rowCount++;
                    sectionCount++;
                    
                    // Create the artist object and add it to the
                    // array for this section if not named .AppleDouble
                    if (![[artist attribute:@"name"] isEqualToString:@".AppleDouble"])
                    {
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

@end
