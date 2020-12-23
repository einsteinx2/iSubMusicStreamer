//
//  SUSTagAlbumLoader.m
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSTagAlbumLoader.h"
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

@implementation SUSTagAlbumLoader

#pragma mark Loader Methods

- (SUSLoaderType)type {
    return SUSLoaderType_TagAlbum;
}

- (NSURLRequest *)createRequest {
    return [NSMutableURLRequest requestWithSUSAction:@"getAlbum" parameters:@{@"id": n2N(self.albumId)}];
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
            
            [root iterate:@"album.song" usingBlock: ^(RXMLElement *e) {
                ISMSSong *song = [[ISMSSong alloc] initWithRXMLElement:e];
                if (song.path && (settingsS.isVideoSupported || !song.isVideo)) {
                    // Fix for pdfs showing in directory listing
                    if (![song.suffix.lowercaseString isEqualToString:@"pdf"]) {
                        [self insertSongIntoAlbumCache:song];
                    }
                }
            }];
                        
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark Private DB Methods

- (FMDatabaseQueue *)dbQueue {
    return databaseS.serverDbQueue;
}

- (BOOL)resetDb {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"DELETE FROM tagSong WHERE albumId = ?", self.albumId];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSTagAlbumLoader] Error resetting tagSong cache tables %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertSongIntoAlbumCache:(ISMSSong *)song {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO tagSong (albumId, songId) VALUES (?, ?)", self.albumId, song.songId];
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSTagAlbumLoader] Error inserting song %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError && [song updateMetadataCache];
}

@end
