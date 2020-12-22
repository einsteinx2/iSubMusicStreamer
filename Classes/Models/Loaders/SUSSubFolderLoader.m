//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSSubFolderLoader.h"
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

@implementation SUSSubFolderLoader

#pragma mark - Loader Methods

- (SUSLoaderType)type {
    return SUSLoaderType_SubFolders;
}

- (NSURLRequest *)createRequest {
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:@{@"id": n2N(self.folderId)}];
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
            self.folderAlbumsCount = 0;
            self.songsCount = 0;
            self.folderLength = 0;
            
            NSMutableArray *folderAlbums = [[NSMutableArray alloc] initWithCapacity:0];
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue]) {
                    ISMSFolderAlbum *folderAlbum = [[ISMSFolderAlbum alloc] initWithElement:e folderArtist:self.folderArtist];
                    if (![folderAlbum.title isEqualToString:@".AppleDouble"]) {
                        [folderAlbums addObject:folderAlbum];
                    }
                } else {
                    ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                    if (aSong.path && (settingsS.isVideoSupported || !aSong.isVideo)) {
                        // Fix for pdfs showing in directory listing
                        if (![aSong.suffix.lowercaseString isEqualToString:@"pdf"]) {
                            [self insertSongIntoFolderCache:aSong];
                            self.songsCount++;
                            self.folderLength += [aSong.duration intValue];
                        }
                    }
                }
            }];
            
            // Hack for Subsonic 4.7 breaking alphabetical order
            [folderAlbums sortUsingComparator:^NSComparisonResult(ISMSFolderAlbum *obj1, ISMSFolderAlbum *obj2) {
                return [obj1.title caseInsensitiveCompareWithoutIndefiniteArticles:obj2.title];
            }];
            for (ISMSFolderAlbum *folderAlbum in folderAlbums) {
                [self insertFolderAlbumIntoFolderCache:folderAlbum];
            }
            self.folderAlbumsCount = folderAlbums.count;
            //
            
            [self insertFolderAlbumsCount];
            [self insertSongsCount];
            [self insertFolderLength];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark - Private DB Methods

- (FMDatabaseQueue *)dbQueue {
    return databaseS.albumListCacheDbQueue;
}

- (BOOL)resetDb {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        //Initialize the arrays.
        [db beginTransaction];
        NSString *md5 = self.folderId.md5;
        [db executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", md5];
        [db executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", md5];
        [db executeUpdate:@"DELETE FROM albumsCacheCount WHERE folderId = ?", md5];
        [db executeUpdate:@"DELETE FROM songsCacheCount WHERE folderId = ?", md5];
        [db executeUpdate:@"DELETE FROM folderLength WHERE folderId = ?", md5];
        [db commit];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertFolderAlbumIntoFolderCache:(ISMSFolderAlbum *)folderAlbum {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", self.folderId.md5, folderAlbum.title, folderAlbum.folderId, folderAlbum.coverArtId, folderAlbum.folderArtistName, folderAlbum.folderArtistId];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertSongIntoFolderCache:(ISMSSong *)aSong {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], self.folderId.md5, aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size, aSong.parentId, NSStringFromBOOL(aSong.isVideo), aSong.discNumber];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err inserting song %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertFolderAlbumsCount {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO albumsCacheCount (folderId, count) VALUES (?, ?)", self.folderId.md5, @(self.folderAlbumsCount)];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err inserting album count %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertSongsCount {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO songsCacheCount (folderId, count) VALUES (?, ?)", self.folderId.md5, @(self.songsCount)];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err inserting song count %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

- (BOOL)insertFolderLength {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO folderLength (folderId, length) VALUES (?, ?)", self.folderId.md5, @(self.folderLength)];
        
        hadError = db.hadError;
        if (hadError) {
            DDLogError(@"[SUSSubFolderLoader] Err inserting folder length %d: %@", db.lastErrorCode, db.lastErrorMessage);
        }
    }];
    return !hadError;
}

@end
