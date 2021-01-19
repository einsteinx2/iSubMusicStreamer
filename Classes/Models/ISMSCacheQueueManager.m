//
//  ISMSCacheQueueManager.m
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ISMSCacheQueueManager.h"
#import "ISMSStreamManager.h"
#import "ISMSStreamHandler.h"
#import "RXMLElement.h"
#import "ISMSNSURLSessionStreamHandler.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "ISMSStreamManager.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

#define maxNumOfReconnects 5

@implementation ISMSCacheQueueManager

#pragma mark Download Methods

- (BOOL)isSongInQueue:(ISMSSong *)aSong {
    // TODO: implement this
//	return [databaseS.cacheQueueDbQueue boolForQuery:@"SELECT COUNT(*) FROM cacheQueue WHERE songId = ? LIMIT 1", aSong.songId];
}

- (ISMSSong *)currentQueuedSongInDb {
    return [Store.shared firstSongInDownloadQueue];
    
//	__block ISMSSong *aSong = nil;
//	[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db) {
//		 FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' ORDER BY ROWID ASC LIMIT 1"];
//		 if ([db hadError]) {
//			 //DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
//		 } else {
//			 aSong = [ISMSSong songFromDbResult:result];
//		 }
//
//		 [result close];
//	 }];
//
//	return aSong;
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{
    if (self.isQueueDownloading) return;
    	
	// Check if there's another queued song and that were are on Wifi
	self.currentQueuedSong = self.currentQueuedSongInDb;
	if (!self.currentQueuedSong || (!AppDelegate.shared.isWifi && !settingsS.isManualCachingOnWWANEnabled) || settingsS.isOfflineMode) {
		return;
    }
    
    DDLogInfo(@"[ISMSCacheQueueManager] starting download queue for: %@", self.currentQueuedSong);
	
	// For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
	if (cacheS.freeSpace <= 25 * 1024 * 1024) {
		/*[EX2Dispatch runInMainThread:^
		 {
			 [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot download any more music. Please free some space and try again", @"Download manager, device out of space message")];
		 }];*/
		
		return;
	}
    
    // Check if this is a video
    if (self.currentQueuedSong.isVideo) {
        // Remove from the queue
        (void)[Store.shared removeFromDownloadQueueWithSong:self.currentQueuedSong];
        
        // Continue the queue
		[self startDownloadQueue];
        
        return;
    }
	
	// Check if the song is fully cached and if so, remove it from the queue and return
	if (self.currentQueuedSong.isFullyCached) {
        DDLogInfo(@"[ISMSCacheQueueManager] Marking %@ as downloaded because it's already fully cached", self.currentQueuedSong.title);
		
		// Mark it as downloaded
        (void)[Store.shared updateWithDownloadFinished:YES song:self.currentQueuedSong];
		
		// The song is fully cached, so delete it from the cache queue database
        (void)[Store.shared removeFromDownloadQueueWithSong:self.currentQueuedSong];
		
		// Notify any tables
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@(self.currentQueuedSong.songId) forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded userInfo:userInfo];
		
		// Continue the queue
		[self startDownloadQueue];
        
		return;
	}
	
	self.isQueueDownloading = YES;
	
	// Grab the lyrics
	if (self.currentQueuedSong.tagArtistName && self.currentQueuedSong.title) {
        NSString *tagArtistName = self.currentQueuedSong.tagArtistName;
        NSString *title = self.currentQueuedSong.title;
        if (![Store.shared isLyricsCachedWithTagArtistName:tagArtistName songTitle:title]) {
            [[[LyricsLoader alloc] initWithTagArtistName:tagArtistName songTitle:title delegate:nil] startLoad];
        }
	}
	
	// Download the art
	if (self.currentQueuedSong.coverArtId) {
		NSString *coverArtId = self.currentQueuedSong.coverArtId;
		CoverArtLoader *playerArt = [[CoverArtLoader alloc] initWithCoverArtId:coverArtId isLarge:YES delegate:nil];
		(void)[playerArt downloadArtIfNotExists];
		
		CoverArtLoader *tableArt = [[CoverArtLoader alloc] initWithCoverArtId:coverArtId isLarge:NO delegate:nil];
		(void)[tableArt downloadArtIfNotExists];
	}
	
	// Create the stream handler
	ISMSStreamHandler *handler = [streamManagerS handlerForSong:self.currentQueuedSong];
	if (handler) {
        DDLogInfo(@"[ISMSCacheQueueManager] stealing %@ from stream manager", handler.mySong.title);
		
		// It's in the stream queue so steal the handler
		self.currentStreamHandler = handler;
		self.currentStreamHandler.delegate = self;
		[streamManagerS stealHandlerForCacheQueue:handler];
		if (!self.currentStreamHandler.isDownloading) {
			[self.currentStreamHandler start:YES];
		}
	} else {
        DDLogInfo(@"[ISMSCacheQueueManager] CQ creating download handler for %@", self.currentQueuedSong.title);
		self.currentStreamHandler = [[ISMSNSURLSessionStreamHandler alloc] initWithSong:self.currentQueuedSong isTemp:NO delegate:self];
		self.currentStreamHandler.partialPrecacheSleep = NO;
		[self.currentStreamHandler start];
	}
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueStarted];
}

- (void)resumeDownloadQueue:(NSNumber *)byteOffse {
	// Create the request and resume the download
	if (!settingsS.isOfflineMode) {
		[self.currentStreamHandler start:YES];
	}
}

- (void)stopDownloadQueue {
    if (!self.isQueueDownloading) return;
    
    //DLog(@"stopping download queue");
	self.isQueueDownloading = NO;
	
	[self.currentStreamHandler cancel];
	self.currentStreamHandler = nil;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueStopped];
}

- (void)removeCurrentSong {
	if (self.isQueueDownloading)
		[self stopDownloadQueue];
	
    (void)[Store.shared removeFromDownloadQueueWithSong:self.currentQueuedSong];
	
	if (!self.isQueueDownloading)
		[self startDownloadQueue];
}

#pragma mark ISMSStreamHandler Delegate

- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSStreamHandler *)handler {
	// Don't ever partial pre-cache
	handler.partialPrecacheSleep = NO;
}

- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler {
	[streamManagerS ISMSStreamHandlerStartPlayback:handler];
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error {
	if (handler.numOfReconnects < maxNumOfReconnects) {
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeDownloadQueue:) withObject:nil afterDelay:2.0];
	} else {
        [SlidingNotification showOnMainWindowWithMessage:NSLocalizedString(@"Song failed to download", @"Download manager, download failed message")];
		
		// Tried max number of times so remove
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongFailed];
        (void)[Store.shared removeFromDownloadQueueWithSong:self.currentQueuedSong];
		self.currentStreamHandler = nil;
		[self startDownloadQueue];
	}
}

//static BOOL isAlertDisplayed = NO;
- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler {
    NSDate *start = [NSDate date];
	BOOL isSuccess = YES;
	if (handler.totalBytesTransferred == 0) {
		// Not a trial issue, but no data was returned at all
        NSString *message = @"We asked to cache a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed.\n\nIf you need help, please tap the Support button on the Home tab.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uh oh!"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        
		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
		isSuccess = NO;
	} else if (handler.totalBytesTransferred < 1000) {
		// Verify that it's a license issue
		NSData *receivedData = [NSData dataWithContentsOfFile:handler.filePath];
        RXMLElement *root = [[RXMLElement alloc] initFromXMLData:receivedData];
        if (root.isValid) {
            RXMLElement *error = [root child:@"error"];
            if (error.isValid) {
                if ([[error attribute:@"code"] integerValue] == 60) {
                    // This is a trial period message, alert the user and stop streaming
                    NSString *message = @"You can purchase a license for Subsonic by logging in to the web interface and clicking the red Donate link on the top right.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.";
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic API Trial Expired"
                                                                                   message:message
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
 
                    [[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
                    isSuccess = NO;
                }
            }
        }
	}
	
	if (isSuccess) {
		// Mark song as cached
        (void)[Store.shared updateWithDownloadFinished:YES song:self.currentQueuedSong];
		
		// Remove the song from the cache queue
        (void)[Store.shared removeFromDownloadQueueWithSong:self.currentQueuedSong];
		self.currentQueuedSong = nil;
        		
		// Remove the stream handler
		self.currentStreamHandler = nil;
		
		// Tell the cache queue view to reload
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@(handler.mySong.songId) forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded userInfo:userInfo];
		
		// Download the next song in the queue
        self.isQueueDownloading = NO;
		[self startDownloadQueue];
	} else {
		[self stopDownloadQueue];
	}
    
    DDLogInfo(@"[ISMSCacheQueueManager] finished download took %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
}

#pragma mark Singleton methods

+ (instancetype)sharedInstance {
    static ISMSCacheQueueManager *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

@end
