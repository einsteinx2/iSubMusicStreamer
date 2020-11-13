//
//  SUSQueueAllLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQueueAllLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "NSError+ISMSError.h"
#import "ISMSArtist.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@interface SUSQueueAllLoader()
@property (strong) NSData *receivedData;
@end

@implementation SUSQueueAllLoader

@synthesize receivedData;

- (void)startLoad {
    [NSException raise:NSInternalInconsistencyException format:@"must use loadData:artist:"];
}

- (void)cancelLoad {
    //DLog(@"cancelLoad called");
    self.isCancelled = YES;
    [super cancelLoad];
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_HideLoadingScreen];
}

- (void)finishLoad {
    if (self.isCancelled) return;
    
    // Continue the iteration
    if (self.folderIds.count > 0) {
        [self loadAlbumFolder];
    } else {
        if (self.isShuffleButton) {
            // Perform the shuffle
            if (settingsS.isJukeboxEnabled) {
                [jukeboxS jukeboxClearRemotePlaylist];
            }
            
            [databaseS shufflePlaylist];
            
            if (settingsS.isJukeboxEnabled) {
                [jukeboxS jukeboxReplacePlaylistWithLocal];
            }
        }
        
        if (self.isQueue) {
            if (settingsS.isJukeboxEnabled) {
                //[jukeboxS jukeboxReplacePlaylistWithLocal];
            } else {
                [streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
            }
        }
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_HideLoadingScreen];
        
        if (self.doShowPlayer) {
            [musicS showPlayer];
        }
    }
}

- (void)loadAlbumFolder {
	if (self.isCancelled) return;
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:@{@"id": self.folderIds.firstObject}];
    
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            // Inform the delegate that loading failed
            [self informDelegateLoadingFailed:error];
        } else {
            self.receivedData = data;
            
            // Parse the data
            [self process];
            
            // Add the songs
            for (ISMSSong *aSong in self.listOfSongs) {
                if (self.isQueue) {
                    [aSong addToCurrentPlaylistDbQueue];
                } else {
                    [aSong addToCacheQueueDbQueue];
                }
            }
            [self.listOfSongs removeAllObjects];
            
            // Remove the processed folder from array
            if (self.folderIds.count > 0) {
                [self.folderIds removeObjectAtIndex:0];
            }
            
            for (NSInteger i = self.listOfAlbums.count - 1; i >= 0; i--) {
                NSString *albumId = [[self.listOfAlbums objectAtIndexSafe:i] albumId];
                [self.folderIds insertObject:albumId atIndex:0];
            }
            [self.listOfAlbums removeAllObjects];
            
            self.receivedData = nil;
            
            // Continue the iteration
            if (self.isQueue) {
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
            }
            
            [self finishLoad];
        }
    }];
    [dataTask resume];
}

- (void)loadData:(NSString *)folderId artist:(ISMSArtist *)theArtist {
    if (!folderId) {
        [self informDelegateLoadingFailed:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection]];
        return;
    }
    
    self.folderIds = [NSMutableArray arrayWithCapacity:0];
    self.listOfSongs = [NSMutableArray arrayWithCapacity:0];
    self.listOfAlbums = [NSMutableArray arrayWithCapacity:0];
    
    self.isCancelled = NO;
    
    [self.folderIds addObject:folderId];
    self.myArtist = theArtist;
        
    if (settingsS.isJukeboxEnabled) {
        self.currentPlaylist = @"jukeboxCurrentPlaylist";
        self.shufflePlaylist = @"jukeboxShufflePlaylist";
    } else {
        self.currentPlaylist = @"currentPlaylist";
        self.shufflePlaylist = @"shufflePlaylist";
    }
    
    [self loadAlbumFolder];
}

- (void)queueData:(NSString *)folderId artist:(ISMSArtist *)theArtist {
    self.isQueue = YES;
    self.isShuffleButton = NO;
    self.doShowPlayer = NO;
    [self loadData:folderId artist:theArtist];
}

- (void)cacheData:(NSString *)folderId artist:(ISMSArtist *)theArtist {
    self.isQueue = NO;
    self.isShuffleButton = NO;
    self.doShowPlayer = NO;
    [self loadData:folderId artist:theArtist];
}

- (void)playAllData:(NSString *)folderId artist:(ISMSArtist *)theArtist {
    self.isQueue = YES;
    self.isShuffleButton = NO;
    self.doShowPlayer = YES;
    [self loadData:folderId artist:theArtist];
}

- (void)shuffleData:(NSString *)folderId artist:(ISMSArtist *)theArtist {
    self.isQueue = YES;
    self.isShuffleButton = YES;
    self.doShowPlayer = YES;
    [self loadData:folderId artist:theArtist];
}

- (void)process {
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
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue]) {
                    ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:e artistId:self.myArtist.artistId artistName:self.myArtist.name];
                    if (![anAlbum.title isEqualToString:@".AppleDouble"]) {
                        [self.listOfAlbums addObject:anAlbum];
                    }
                } else {
                    ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                    if (aSong.path && (settingsS.isVideoSupported || !aSong.isVideo)) {
                        // Fix for pdfs showing in directory listing
                        if (![aSong.suffix.lowercaseString isEqualToString:@"pdf"]) {
                            [self.listOfSongs addObject:aSong];
                        }
                    }
                }
            }];
		}
	}	
}

@end
