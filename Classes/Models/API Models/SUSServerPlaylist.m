//
//  SUSServerPlaylist.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylist.h"
#import "RXMLElement.h"
#import "EX2Kit.h"
#import "DatabaseSingleton.h"
//#import "ISMSSong+DAO.h"
#import "ViewObjectsSingleton.h"
#import "SUSLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "Defines.h"

@implementation SUSServerPlaylist

- (instancetype)initWithRXMLElement:(RXMLElement *)element {
    if (self = [super init]) {
        _playlistId = [element attribute:@"id"];
        _playlistName = [[element attribute:@"name"] cleanString];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *) zone {
    SUSServerPlaylist *playlist = [[SUSServerPlaylist alloc] init];
    playlist.playlistName = self.playlistName;
    playlist.playlistId = self.playlistId;
    return playlist;
}

- (NSComparisonResult)compare:(SUSServerPlaylist *)otherObject  {
    return [self.playlistName caseInsensitiveCompare:otherObject.playlistName];
}

- (void)loadSongsAndQueueOrDownload:(BOOL)isDownload {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:@{@"id": n2N(self.playlistId)}];
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // TODO: Inform user of errors
        if (!error) {
            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
            if (!root.isValid) {
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
                // TODO: handle this error
            } else {
                RXMLElement *error = [root child:@"error"];
                if (error.isValid) {
                    //NSString *code = [error attribute:@"code"];
                    //NSString *message = [error attribute:@"message"];
                    // TODO: handle this error
                } else {
                    // TODO: Handle !isValid case
//                    if ([[root child:@"playlist"] isValid]) {
//                        NSString *md5 = [self.playlistName md5];
//                        [databaseS removeServerPlaylistTable:md5];
//                        [databaseS createServerPlaylistTable:md5];
//                        
//                        [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
//                            ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
//                            [aSong insertIntoServerPlaylistWithPlaylistId:md5];
//                            if (isDownload) {
//                                [aSong addToDownloadQueue];
//                            } else {
//                                [aSong addToCurrentPlaylistDbQueue];
//                            }
//                        }];
//                    }
                }
            }
        }
        
        [EX2Dispatch runInMainThreadAsync:^{
            [viewObjectsS hideLoadingScreen];
        }];
        
        if (!isDownload) {
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
        }
    }];
    [dataTask resume];
}

#pragma mark Table Cell Model

- (NSString *)primaryLabelText { return self.playlistName; }
- (NSString *)secondaryLabelText { return nil; }
- (NSString *)durationLabelText { return nil; }
- (NSString *)coverArtId { return nil; }
- (BOOL)isCached { return NO; }
- (void)download { [self loadSongsAndQueueOrDownload:YES]; }
- (void)queue { [self loadSongsAndQueueOrDownload:NO]; }

@end
