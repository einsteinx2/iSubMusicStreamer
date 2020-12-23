//
//  SUSRootArtistsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSRootArtistsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation SUSRootArtistsLoader

- (SUSLoaderType)type {
    return SUSLoaderType_RootArtists;
}

#pragma mark Data loading

- (NSURLRequest *)createRequest {
    NSDictionary *parameters = nil;
    if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        parameters = @{@"musicFolderId": n2N([self.selectedFolderId stringValue])};
    }
    
    return [NSMutableURLRequest requestWithSUSAction:@"getArtists" parameters:parameters];
}

- (void)processResponse {
    // Clear the database
    [self resetRootArtistCache];
    
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
                        // Add the artist to the DB
                        ISMSTagArtist *tagArtist = [[ISMSTagArtist alloc] initWithElement:artist];
                        if ([self addRootArtistToMainCache:tagArtist]) {
                            rowCount++;
                            sectionCount++;
                        }
                    }
                }
                
                NSString *indexName = [[e attribute:@"name"] cleanString];
                [self addRootArtistIndexToCache:rowIndex count:sectionCount name:indexName];
            }];
            
            // Update the count
            [self rootArtistUpdateCount];
            
            // Save the reload time
            [settingsS setRootArtistsReloadTime:[NSDate date]];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark Database Methods

- (FMDatabaseQueue *)dbQueue {
    return databaseS.serverDbQueue;
}

- (NSString *)tableModifier {
    NSString *tableModifier = @"_all";
    
    if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        tableModifier = [NSString stringWithFormat:@"_%@", [self.selectedFolderId stringValue]];
    }
    
    return tableModifier;
}

- (NSUInteger)rootArtistUpdateCount {
    __block NSNumber *folderCount = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"DELETE FROM rootArtistCount%@", self.tableModifier];
         [db executeUpdate:query];
         
         query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM rootArtistCache%@", self.tableModifier];
         folderCount = @([db intForQuery:query]);
         
         query = [NSString stringWithFormat:@"INSERT INTO rootArtistCount%@ VALUES (?)", self.tableModifier];
         [db executeUpdate:query, folderCount];
         
     }];
    return [folderCount intValue];
}

- (void)resetRootArtistCache {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         // Delete the old tables
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootArtistIndexCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootArtistCache%@", self.tableModifier]];
         [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS rootArtistCount%@", self.tableModifier]];
         
         // Create the new tables
         NSString *query;
         query = @"CREATE TABLE rootArtistIndexCache%@ (name TEXT PRIMARY KEY, position INTEGER, count INTEGER)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
         query = @"CREATE VIRTUAL TABLE rootArtistCache%@ USING FTS3 (id TEXT PRIMARY KEY, name TEXT, coverArtId TEXT, artistImageUrl TEXT, albumCount INTEGER, tokenize=porter)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
         query = @"CREATE TABLE rootArtistCount%@ (count INTEGER)";
         [db executeUpdate:[NSString stringWithFormat:query, self.tableModifier]];
     }];
}

- (BOOL)addRootArtistIndexToCache:(NSUInteger)position count:(NSUInteger)artistCount name:(NSString*)name {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *query = [NSString stringWithFormat:@"INSERT INTO rootArtistIndexCache%@ VALUES (?, ?, ?)", self.tableModifier];
         [db executeUpdate:query, name, @(position), @(artistCount)];
         hadError = [db hadError];
     }];
    return !hadError;
}

- (BOOL)addRootArtistToMainCache:(ISMSTagArtist *)tagArtist {
    __block BOOL hadError = NO;
    if (tagArtist.artistId && tagArtist.name) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
             NSString *query = [NSString stringWithFormat:@"INSERT INTO rootArtistCache%@ VALUES (?, ?, ?, ?, ?)", self.tableModifier];
             [db executeUpdate:query, tagArtist.artistId, tagArtist.name, tagArtist.coverArtId, tagArtist.artistImageUrl, @(tagArtist.albumCount)];
             hadError = [db hadError];
         }];
    }
    return !hadError;
}

@end
