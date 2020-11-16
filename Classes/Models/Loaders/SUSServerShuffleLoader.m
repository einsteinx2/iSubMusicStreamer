//
//  SUSServerShuffleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSServerShuffleLoader.h"
#import "SearchXMLParser.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation SUSServerShuffleLoader

- (SUSLoaderType)type {
    return SUSLoaderType_ServerShuffle;
}

- (NSURLRequest *)createRequest {
    // Start the 100 record open search to create shuffle list
    NSMutableDictionary *parameters = [@{@"size": @"100"} mutableCopy];
    if (self.folderId) {
        if ([self.folderId intValue] >= 0) {
            parameters[@"musicFolderId"] = n2N([self.folderId stringValue]);
        }
    }
    
    return [NSMutableURLRequest requestWithSUSAction:@"getRandomSongs" parameters:parameters];
}

- (void)processResponse {
    // TODO: Refactor this with RaptureXML
    SearchXMLParser *parserDelegate = [[SearchXMLParser alloc] init];
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
    [xmlParser setDelegate:parserDelegate];
    [xmlParser parse];
    
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    
    for (ISMSSong *aSong in parserDelegate.listOfSongs) {
        [aSong addToCurrentPlaylistDbQueue];
    }
    
    playlistS.isShuffle = NO;    
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    [self informDelegateLoadingFinished];
}

@end
