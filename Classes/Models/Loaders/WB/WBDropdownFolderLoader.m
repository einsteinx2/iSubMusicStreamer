//
//  WBDropdownFolderLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "WBDropdownFolderLoader.h"

@implementation WBDropdownFolderLoader

- (void)startLoad
{
    // pull media folders from database
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *query = @"SELECT folder_name, folder_id FROM folder WHERE folder_media_folder_id IS NULL";
        FMResultSet *result = [db executeQuery:query];
        
        self.updatedfolders = [[NSMutableDictionary alloc] init];
        [self.updatedfolders setObject:@"All Folders" forKey:@-1];
        
        while ([result next])
        {
            // add each one to the updatedfolders list
            NSString *folderName = [result stringForColumn:@"folder_name"];
            NSNumber *folderId = @([result intForColumn:@"folder_id"]);
            
            [self.updatedfolders setObject:folderName forKey:folderId];
        }
    }];
    
    // tell the delegate we're done
    [self informDelegateLoadingFinished];
}

@end
