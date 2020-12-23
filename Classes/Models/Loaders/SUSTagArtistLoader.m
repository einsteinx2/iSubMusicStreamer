//
//  SUSTagArtistLoader.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSTagArtistLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation SUSTagArtistLoader

#pragma mark Loader Methods

- (SUSLoaderType)type {
    return SUSLoaderType_TagArtist;
}

- (NSURLRequest *)createRequest {
    return [NSMutableURLRequest requestWithSUSAction:@"getArtist" parameters:@{@"id": n2N(self.artistId)}];
}

- (void)processResponse {
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
            [self resetDb];
            
            [root iterate:@"artist.album" usingBlock: ^(RXMLElement *e) {
                ISMSTagAlbum *tagAlbum = [[ISMSTagAlbum alloc] initWithElement:e];
                [self insertAlbumIntoTagAlbumCache:tagAlbum];
            }];
                        
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark Private DB Methods

- (FMDatabaseQueue *)dbQueue {
    return databaseS.albumListCacheDbQueue;
}

- (BOOL)resetDb {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        //Initialize the arrays.
        [db beginTransaction];
        [db executeUpdate:@"DELETE FROM tagAlbum WHERE folderId = ?", self.artistId];
        [db commit];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Error resetting tagAlbum cache tables %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertAlbumIntoTagAlbumCache:(ISMSTagAlbum *)tagAlbum {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO tagAlbum (artistId, albumId, name, coverArtId, tagArtistId, tagArtistName, songCount, duration, playCount, year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", self.artistId, tagAlbum.albumId, tagAlbum.name, tagAlbum.coverArtId, tagAlbum.tagArtistId, tagAlbum.tagArtistName, @(tagAlbum.songCount), @(tagAlbum.duration), @(tagAlbum.playCount), @(tagAlbum.year)];
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSTagArtistLoader] Error inserting tagAlbum %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

@end
