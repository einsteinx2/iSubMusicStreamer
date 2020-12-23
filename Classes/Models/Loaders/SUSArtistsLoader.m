//
//  SUSArtistsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSArtistsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "EX2Kit.h"

@implementation SUSArtistsLoader

- (SUSLoaderType)type {
    return SUSLoaderType_Artists;
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
    [self resetArtistCache];
    
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
            
            [root iterate:@"artists.index" usingBlock:^(RXMLElement *e) {
                sectionCount = 0;
                rowIndex = rowCount + 1;
                
                for (RXMLElement *artist in [e children:@"artist"]) {
                    // Create the artist object and add it to the
                    // array for this section if not named .AppleDouble
                    if (![[artist attribute:@"name"] isEqualToString:@".AppleDouble"]) {
                        // Parse the top level folder
                        NSString *artistId = [artist attribute:@"id"];
                        NSString *name = [[artist attribute:@"name"] cleanString];
                        NSString *coverArtId = [artist attribute:@"coverArtId"];
                        NSString *artistImageUrl = [artist attribute:@"artistImageUrl"];
                        NSNumber *albumCount = @([artist attribute:@"albumCount"].integerValue);
                        
                        // Add the artist to the DB
                        if ([self addArtistToMainCache:artistId name:name coverArtId:coverArtId artistImageUrl:artistImageUrl albumCount:albumCount]) {
                            rowCount++;
                            sectionCount++;
                        }
                    }
                }
                
                NSString *indexName = [[e attribute:@"name"] cleanString];
                [self addArtistIndexToCache:rowIndex count:sectionCount name:indexName];
            }];
            
            // Update the count
            [self artistUpdateCount];
            
            // Save the reload time
            [settingsS setRootFoldersReloadTime:[NSDate date]];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark Database Methods

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

- (NSUInteger)artistUpdateCount {
    __block NSNumber *folderCount = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"DELETE FROM artistCount%@", self.tableModifier];
         [db executeUpdate:query];
         
         query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM artistCache%@", self.tableModifier];
         folderCount = @([db intForQuery:query]);
         
         query = [NSString stringWithFormat:@"INSERT INTO artistCount%@ VALUES (?)", self.tableModifier];
         [db executeUpdate:query, folderCount];
         
     }];
    return [folderCount intValue];
}

- (void)resetArtistCache {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         // Delete the old tables
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS artistIndexCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS artistNameCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS artistCount%@", self.tableModifier]];
         
         // Create the new tables
         NSString *query;
         query = @"CREATE TABLE artistIndexCache%@ (name TEXT PRIMARY KEY, position INTEGER, count INTEGER)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
         query = @"CREATE VIRTUAL TABLE artistCache%@ USING FTS3 (id TEXT PRIMARY KEY, name TEXT, coverArtId TEXT, artistImageUrl TEXT, albumCount INTEGER, tokenize=porter)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
         query = @"CREATE TABLE artistCount%@ (count INTEGER)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
     }];
}

- (BOOL)addArtistIndexToCache:(NSUInteger)position count:(NSUInteger)artistCount name:(NSString*)name {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"INSERT INTO artistIndexCache%@ VALUES (?, ?, ?)", self.tableModifier];
         [db executeUpdate:query, name, @(position), @(artistCount)];
         hadError = [db hadError];
     }];
    return !hadError;
}

- (BOOL)addArtistToMainCache:(NSString *)artistId name:(NSString *)name coverArtId:(NSString *)coverArtId artistImageUrl:(NSString *)artistImageUrl albumCount:(NSNumber *)albumCount {
    __block BOOL hadError = NO;
    if (artistId && name) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
             NSString *query = [NSString stringWithFormat:@"INSERT INTO artistCache%@ VALUES (?, ?, ?, ?, ?)", self.tableModifier];
             [db executeUpdate:query, artistId, name, coverArtId, artistImageUrl, albumCount];
             hadError = [db hadError];
         }];
    }
    return !hadError;
}

@end
