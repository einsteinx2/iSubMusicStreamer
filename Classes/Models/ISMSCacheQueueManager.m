//
//  ISMSCacheQueueManager.m
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSCacheQueueManager.h"
#import "DatabaseSingleton.h"
#import "SUSLyricsLoader.h"
#import "SUSCoverArtLoader.h"
#import "ISMSStreamManager.h"
#import "ISMSStreamHandler.h"
#import "SUSLyricsDAO.h"

#import "ISMSCFNetworkStreamHandler.h"

//LOG_LEVEL_ISUB_DEFAULT
LOG_LEVEL_ISUB_DEBUG

#define maxNumOfReconnects 5

@implementation ISMSCacheQueueManager

#pragma mark Download Methods

- (BOOL)isSongInQueue:(ISMSSong *)aSong
{
	return [databaseS.cacheQueueDbQueue boolForQuery:@"SELECT COUNT(*) FROM cacheQueue WHERE songId = ? LIMIT 1", aSong.songId];
}

- (ISMSSong *)currentQueuedSongInDb
{
	__block ISMSSong *aSong = nil;
	
	[databaseS.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	 {
		 FMResultSet *result = [db executeQuery:@"SELECT * FROM cacheQueue WHERE finished = 'NO' LIMIT 1"];
		 if ([db hadError]) 
		 {
			 //DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		 }
		 else
		 {
			 aSong = [ISMSSong songFromDbResult:result];
		 }
		 
		 [result close]; 
	 }];
	
	return aSong;
}

// Start downloading the file specified in the text field.
- (void)startDownloadQueue
{    
	// Are we already downloading?  If so, stop it.
	[self stopDownloadQueue];
	
	//DLog(@"starting download queue");
	
	// Check if there's another queued song and that were are on Wifi
	self.currentQueuedSong = self.currentQueuedSongInDb;
#ifdef IOS
	if (!self.currentQueuedSong || (![LibSub isWifi] && !settingsS.isManualCachingOnWWANEnabled) || settingsS.isOfflineMode)
#else
    if (!self.currentQueuedSong || settingsS.isOfflineMode)
#endif
    {
		return;
    }
    
    DDLogVerbose(@"[ISMSCacheQueueManager] starting download queue for: %@", self.currentQueuedSong);
	
	// For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
	if (cacheS.freeSpace <= BytesFromMiB(25))
	{
		/*[EX2Dispatch runInMainThread:^
		 {
			 [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot download any more music. Please free some space and try again", @"Download manager, device out of space message")];
		 }];*/
		
		return;
	}
    
    // Check if this is a video
    if (self.currentQueuedSong.isVideo)
    {
        // Remove from the queue
        [self.currentQueuedSong removeFromCacheQueueDbQueue];
        
        // Continue the queue
		[self startDownloadQueue];
        
        return;
    }
	
	// Check if the song is fully cached and if so, remove it from the queue and return
	if (self.currentQueuedSong.isFullyCached)
	{
		DDLogVerbose(@"[ISMSCacheQueueManager] Marking %@ as downloaded because it's already fully cached", self.currentQueuedSong.title);
		
		// Mark it as downloaded
		//self.currentQueuedSong.isDownloaded = YES;
		
		// The song is fully cached, so delete it from the cache queue database
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		
		// Notify any tables
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentQueuedSong.songId forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded userInfo:userInfo];
		
		// Continue the queue
		[self startDownloadQueue];
        
		return;
	}
	
	self.isQueueDownloading = YES;
	
	// Grab the lyrics
	if (self.currentQueuedSong.artist && self.currentQueuedSong.title)
	{
        [self.lyricsDAO loadLyricsForArtist:self.currentQueuedSong.artist andTitle:self.currentQueuedSong.title];    
	}
	
	// Download the art
	if (self.currentQueuedSong.coverArtId)
	{
		NSString *coverArtId = self.currentQueuedSong.coverArtId;
		SUSCoverArtLoader *playerArt = [[SUSCoverArtLoader alloc] initWithDelegate:nil coverArtId:coverArtId isLarge:YES];
		[playerArt downloadArtIfNotExists];
		
		SUSCoverArtLoader *tableArt = [[SUSCoverArtLoader alloc] initWithDelegate:nil coverArtId:coverArtId isLarge:NO];
		[tableArt downloadArtIfNotExists];
	}
	
	// Create the stream handler
	ISMSStreamHandler *handler = [streamManagerS handlerForSong:self.currentQueuedSong];
	if (handler)
	{
		DDLogVerbose(@"[ISMSCacheQueueManager] stealing %@ from stream manager", handler.mySong.title);
		
		// It's in the stream queue so steal the handler
		self.currentStreamHandler = handler;
		self.currentStreamHandler.delegate = self;
		[streamManagerS stealHandlerForCacheQueue:handler];
		if (!self.currentStreamHandler.isDownloading)
		{
			[self.currentStreamHandler start:YES];
		}
	}
	else
	{
		DDLogVerbose(@"[ISMSCacheQueueManager] CQ creating download handler for %@", self.currentQueuedSong.title);
		self.currentStreamHandler = [[ISMSCFNetworkStreamHandler alloc] initWithSong:self.currentQueuedSong isTemp:NO delegate:self];
		self.currentStreamHandler.partialPrecacheSleep = NO;
		[self.currentStreamHandler start];
	}
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueStarted];
}

- (void)resumeDownloadQueue:(NSNumber *)byteOffset
{
	// Create the request and resume the download
	if (!settingsS.isOfflineMode)
	{
		[self.currentStreamHandler start:YES];
	}
}

- (void)stopDownloadQueue
{
    //DLog(@"stopping download queue");
	self.isQueueDownloading = NO;
	
	[self.currentStreamHandler cancel];
	self.currentStreamHandler = nil;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueStopped];
}

- (void)removeCurrentSong
{
	if (self.isQueueDownloading)
		[self stopDownloadQueue];
	
	[self.currentQueuedSong removeFromCacheQueueDbQueue];
	
	if (!self.isQueueDownloading)
		[self startDownloadQueue];
}

#pragma mark - ISMSStreamHandler Delegate

- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSStreamHandler *)handler
{
	// Don't ever partial pre-cache
	handler.partialPrecacheSleep = NO;
}

- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler
{
	[streamManagerS ISMSStreamHandlerStartPlayback:handler];
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error
{
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeDownloadQueue:) withObject:nil afterDelay:2.0];
	}
	else
	{
#ifdef IOS
		[[EX2SlidingNotification slidingNotificationOnTopViewWithMessage:NSLocalizedString(@"Song failed to download", @"Download manager, download failed message") image:nil] showAndHideSlidingNotification];
#endif
		
		// Tried max number of times so remove
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongFailed];
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		self.currentStreamHandler = nil;
		[self startDownloadQueue];
	}
}

//static BOOL isAlertDisplayed = NO;
- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler
{
    NSDate *start = [NSDate date];
    
	BOOL isSuccess = YES;
	
	if (handler.totalBytesTransferred == 0)
	{
		// Not a trial issue, but no data was returned at all
#ifdef IOS
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"We asked to cache a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed.\n\nIf you need help, please tap the Support button on the Home tab." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
#endif
		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
		isSuccess = NO;
	}
	else if (handler.totalBytesTransferred < 1000)
	{
		BOOL isLicenseIssue = NO;
		// Verify that it's a license issue
		NSData *receivedData = [NSData dataWithContentsOfFile:handler.filePath];
		NSError *error;
		TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData error:&error];
		if (!error)
		{
			TBXMLElement *root = tbxml.rootXMLElement;
			
			TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
			if (error)
			{
				NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
				//NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
				if ([code isEqualToString:@"60"])
				{
					isLicenseIssue = YES;
				}
			}
		}
		
		if (isLicenseIssue)
		{
			// This is a trial period message, alert the user and stop streaming
#ifdef IOS
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic API Trial Expired" message:@"You can purchase a license for Subsonic by logging in to the web interface and clicking the red Donate link on the top right.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.\n\nIf you didn't know about the Subsonic license requirement, and do not wish to purchase it, please tap the Support button on the Home tab and contact iSub support for a refund." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];
#endif
			[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
			isSuccess = NO;
		}	
	}
	
	if (isSuccess)
	{		
		// Mark song as cached
        self.currentQueuedSong.isFullyCached = YES;
		
		// Remove the song from the cache queue
		[self.currentQueuedSong removeFromCacheQueueDbQueue];
		self.currentQueuedSong = nil;
        		
		// Remove the stream handler
		self.currentStreamHandler = nil;
		
		// Tell the cache queue view to reload
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:handler.mySong.songId forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheQueueSongDownloaded userInfo:userInfo];
		
		// Download the next song in the queue
		[self startDownloadQueue];
	}
	else 
	{
		[self stopDownloadQueue];
	}
    
    ALog(@"finished download took %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    //DLog(@"received memory warning");
	
}

#pragma mark - Singleton methods

- (void)setup
{
	//self.contentLength = ULLONG_MAX;
    
    self.lyricsDAO = [[SUSLyricsDAO alloc] init];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (id)sharedInstance
{
    static ISMSCacheQueueManager *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
