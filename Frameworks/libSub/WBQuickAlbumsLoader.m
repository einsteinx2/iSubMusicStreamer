//
//  WBQuickAlbumsLoader.m
//  libSub
//
//  Created by Justin Hill on 1/31/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "WBQuickAlbumsLoader.h"

@implementation WBQuickAlbumsLoader

-(void)startLoad
{
    NSString *query;
    self.listOfAlbums = [[NSMutableArray alloc] init];
    
    if ([self.modifier isEqualToString:@"random"])
    {
        query = @"SELECT folder.*, art_item.art_id FROM folder LEFT JOIN art_item ON folder.folder_id = art_item.item_id JOIN song ON song_folder_id = folder_id GROUP BY folder_id ORDER BY random() LIMIT 20";
    }
    else if ([self.modifier isEqualToString:@"frequent"])
    {
        
    }
    else if ([self.modifier isEqualToString:@"newest"])
    {
        query = @"SELECT folder.*, art_item.art_id FROM folder LEFT JOIN art_item ON folder.folder_id = art_item.item_id LEFT JOIN item ON folder.folder_id = item.item_id JOIN song ON song_folder_id = folder_id GROUP BY folder_id ORDER BY item.time_stamp DESC LIMIT 20";
    }
    else if ([self.modifier isEqualToString:@"recent"])
    {
    }
    
    if (self.offset > 0)
    {
        query = [query stringByAppendingFormat:@" OFFSET %lu", (unsigned long)self.offset];
    }
    
    if (query != nil)
    {
        [[databaseS metadataDbQueue] inDatabase:^(FMDatabase *db) {
        
            FMResultSet *result = [db executeQuery:query];
            
            while ([result next])
            {
                @autoreleasepool
                {
                    NSDictionary *dict = @{
                                           @"folderName" : [result stringForColumn:@"folder_name"] ? [result stringForColumn:@"folder_name"] : [NSNull null],
                                           @"folderId" : [result stringForColumn:@"folder_id"] ? [result stringForColumn:@"folder_id"] : [NSNull null],
                                           @"artId" : [result stringForColumn:@"art_id"] ? [result stringForColumn:@"art_id"] : [NSNull null]
                                           };
                    
                    ISMSAlbum *a = [[ISMSAlbum alloc] initWithPMSDictionary:dict];
                    [self.listOfAlbums addObject:a];
                }
            }
            [result close];
            
            ALog(@"%@", self.listOfAlbums);
            
        }];
    }
    // Notify the delegate that the loading is finished
    [self informDelegateLoadingFinished];
}

@end
