//
//  ISMSStreamManager.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamManager.h"
#import "ISMSStreamHandler.h"
#import "ISMSNSURLSessionStreamHandler.h"
#import "PlaylistSingleton.h"
#import "SUSCoverArtLoader.h"
#import "SUSLyricsDAO.h"
#import "ISMSCacheQueueManager.h"
#import "RXMLElement.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

LOG_LEVEL_ISUB_DEFAULT
#define maxNumOfReconnects 5

@implementation ISMSStreamManager

- (ISMSSong *)currentStreamingSong
{
	if (!self.isQueueDownloading)
		return nil;
	
	ISMSStreamHandler *handler = [self.handlerStack firstObject];
	return handler.mySong;
}

- (ISMSStreamHandler *)handlerForSong:(ISMSSong *)aSong
{
	if (!aSong)
		return nil;
	
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			//DLog(@"handler.mySong: %@    aSong: %@", handler.mySong.title, aSong.title);
			return handler;
		}
	}
	return nil;
}

- (BOOL)isSongFirstInQueue:(ISMSSong *)aSong
{
	if (!aSong)
		return NO;
	
	ISMSStreamHandler *firstHandler = [self.handlerStack firstObject];
	return [aSong isEqualToSong:firstHandler.mySong];
}

- (BOOL)isSongDownloading:(ISMSSong *)aSong
{
	if (!aSong)
		return NO;
	
	return [self handlerForSong:aSong].isDownloading;
}

- (BOOL)isQueueDownloading
{
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (handler.isDownloading)
			return YES;
	}
	return NO;
}

// Main worker method
- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Cancel the handlers
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (![handlersToSkip containsObject:handler])
		{
			// If we're trying to resume, cancel the request
			[NSObject cancelPreviousPerformRequestsWithTarget:self 
													 selector:@selector(resumeHandler:)
													   object:handler];
			
			// Cancel the handler
			[handler cancel];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, just cancel all handlers
	if (!songsToSkip)
	{
		[self cancelAllStreams];
		return;
	}
	
	// Gather the handler objects to cancel
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (ISMSSong *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler)
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreamsExceptForSong:(ISMSSong *)aSong
{
	// If aSong == nil, just cancel all handlers
	if (![self handlerForSong:aSong])
	{
		[self cancelAllStreams];
		return;
	}
	
	// Create the handler array with the one object
	NSArray *handlersToSkip = @[[self handlerForSong:aSong]];
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreams
{
	[self cancelAllStreamsExcept:nil];
}

// Main worker method
- (void)cancelStreamAtIndex:(NSUInteger)index
{
	if (index < [self.handlerStack count])
	{
		// Find the handler object and cancel it
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndexSafe:index];
		
		[handler cancel];
		
		// If we're trying to resume, cancel the request
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:@selector(resumeHandler:)
												   object:handler];
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Get the handler index
	NSUInteger index = [self.handlerStack indexOfObject:handler];
	
	// Cancel the handler
	[self cancelStreamAtIndex:index];
}

// Convenience method
- (void)cancelStreamForSong:(ISMSSong *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Cancel the handler
	[self cancelStream:[self handlerForSong:aSong]];
}

// Main worker method
- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Remove the handlers
	NSArray *handlers = [NSArray arrayWithArray:self.handlerStack];
	for (ISMSStreamHandler *handler in handlers)
	{
		if (![handlersToSkip containsObject:handler])
		{
            [self cancelStream:handler];
            [self.handlerStack removeObject:handler];
            
            if (!handler.mySong.isFullyCached && !handler.mySong.isTempCached && !([cacheQueueManagerS.currentQueuedSong isEqualToSong:handler.mySong] && cacheQueueManagerS.isQueueDownloading))
            {
                DDLogVerbose(@"Removing song from cached songs table: %@", handler.mySong);
                [handler.mySong removeFromCachedSongsTableDbQueue];
            }
			//[handler.mySong removeFromCachedSongsTableDbQueue];
		}
	}
	
	// Start the next handler
	if ([self.handlerStack count] > 0)
	{
		// Get the first handler
		ISMSStreamHandler *handler = [self.handlerStack firstObject];
		
		// If it's not already downloading, start downloading
		if (!handler.isDownloading)
		{
			[handler start];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, remove all handlers
	if (!songsToSkip)
	{
		[self removeAllStreams];
		return;
	}
	
	// Gather the handler objects to skip
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (ISMSSong *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler) 
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreamsExceptForSong:(ISMSSong *)aSong
{
	// If aSong == nil, remove all handlers
	if (![self handlerForSong:aSong])
	{
		[self removeAllStreams];
		return;
	}
	
	// Get the handler to skip
	NSArray *handlersToSkip = @[[self handlerForSong:aSong]];
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreams
{
	[self cancelAllStreams];
	[self removeAllStreamsExcept:nil];
}

// Main worker method
- (void)removeStreamAtIndex:(NSUInteger)index
{
	if (index < [self.handlerStack count])
	{
		[self cancelStreamAtIndex:index];
		
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndex:index];
		if (!handler.mySong.isFullyCached && !handler.mySong.isTempCached && !([cacheQueueManagerS.currentQueuedSong isEqualToSong:handler.mySong] && cacheQueueManagerS.isQueueDownloading))
        {
            DDLogVerbose(@"Removing song from cached songs table: %@", handler.mySong);
            [handler.mySong removeFromCachedSongsTableDbQueue];
        }
        [self.handlerStack removeObjectAtIndexSafe:index];
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)removeStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Remove the handler
	[self removeStreamAtIndex:[self.handlerStack indexOfObject:handler]];
}

// Convenience method
- (void)removeStreamForSong:(ISMSSong *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Remove the handler
	[self removeStream:[self handlerForSong:aSong]];
}

- (void)resumeQueue
{
	[self resumeHandler:[self.handlerStack firstObject]];
}

- (void)resumeHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return; 
	
	// As an added check, verify that this handler is still in the stack
	if ([self isSongInQueue:handler.mySong])
	{
		if (cacheQueueManagerS.isQueueDownloading && [cacheQueueManagerS.currentQueuedSong isEqualToSong:handler.mySong])
		{
			// This song is already being downloaded by the cache queue, so just start the player
			[self ISMSStreamHandlerStartPlayback:handler];
			
			// Remove the handler from the stack
			[self removeStream:handler];
			
			// Start the next handler which is now the first object
			if ([self.handlerStack count] > 0)
			{
				ISMSStreamHandler *handler = [self.handlerStack firstObject];
				[self startHandler:handler];
			}
		}
		else
		{
			[handler start:YES];
		}
	}
}

- (void)startHandler:(ISMSStreamHandler *)handler resume:(BOOL)resume
{
	if (!handler)
		return;
	
	if (cacheQueueManagerS.isQueueDownloading && [cacheQueueManagerS.currentQueuedSong isEqualToSong:handler.mySong])
	{
		// This song is already being downloaded by the cache queue, so just start the player
		[self ISMSStreamHandlerStartPlayback:handler];
		
		// Remove the handler from the stack
		[self removeStream:handler];
		
		// Start the next handler which is now the first object
		if ([self.handlerStack count] > 0)
		{
			ISMSStreamHandler *handler = [self.handlerStack firstObject];
			[self startHandler:handler];
		}
	}
	else
	{
		[handler start:resume];
		[self.lyricsDAO loadLyricsForArtist:handler.mySong.artist andTitle:handler.mySong.title];
	}
}

- (void)startHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return;
	
	DDLogVerbose(@"[ISMSStreamManager] starting handler, handlerStack: %@", self.handlerStack);
	
	[self startHandler:handler resume:NO];
}

- (void)saveHandlerStack
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.handlerStack requiringSecureCoding:YES error:nil];
	if (data)
	{
		[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"handlerStack"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)loadHandlerStack
{	
	NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"handlerStack"];
    if (data) {
        self.handlerStack = [[NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[NSArray.class, ISMSStreamHandler.class]] fromData:data error:nil] mutableCopy];
    }

	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		handler.delegate = self;
	}
	
	DDLogVerbose(@"[ISMSStreamManager] load handler stack, handlerStack: %@", self.handlerStack);

}

#pragma mark - Handler Stealing

// Hand of handler to cache queue
- (void)stealHandlerForCacheQueue:(ISMSStreamHandler *)handler
{
	DDLogInfo(@"[ISMSStreamManager] cache queue manager stole handler for: %@", handler.mySong.title);
	handler.partialPrecacheSleep = NO;
	[self.handlerStack removeObject:handler];
	[self saveHandlerStack];
	[self fillStreamQueue];
}

#pragma mark Download

- (void)queueStreamForSong:(ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	if (!song)
		return;
	
	ISMSStreamHandler *handler = [[ISMSNSURLSessionStreamHandler alloc] initWithSong:song byteOffset:byteOffset secondsOffset:secondsOffset isTemp:isTemp delegate:self];
	if (![self.handlerStack containsObject:handler]) {
		[self.handlerStack insertObject:handler atIndex:index];
		
		if ([self.handlerStack count] == 1 && isStartDownload) {
			[self startHandler:handler];
		}
		
		// Also download the album art
		if (song.coverArtId)
		{
            SUSCoverArtLoader *playerArt = [[SUSCoverArtLoader alloc] initWithDelegate:nil coverArtId:song.coverArtId isLarge:YES];
			[playerArt downloadArtIfNotExists];
			
			SUSCoverArtLoader *tableArt = [[SUSCoverArtLoader alloc] initWithDelegate:nil coverArtId:song.coverArtId isLarge:NO];
			[tableArt downloadArtIfNotExists];
		}
	}
	
	[self saveHandlerStack];
}

- (void)queueStreamForSong:(ISMSSong *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:index isTempCache:isTemp isStartDownload:isStartDownload];
}

- (void)queueStreamForSong:(ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	[self queueStreamForSong:song byteOffset:byteOffset secondsOffset:secondsOffset atIndex:[self.handlerStack count] isTempCache:isTemp isStartDownload:isStartDownload];
}

- (void)queueStreamForSong:(ISMSSong *)song isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	//DLog(@"queuing stream for song: %@", song.title);
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:[self.handlerStack count] isTempCache:isTemp isStartDownload:isStartDownload];
}

- (BOOL)isSongInQueue:(ISMSSong *)aSong
{
	BOOL isSongInQueue = NO;
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			isSongInQueue = YES;
			break;
		}
	}
	return isSongInQueue;
}

- (void)fillStreamQueue:(BOOL)isStartDownload
{	
	if (settingsS.isJukeboxEnabled)
		return;
	
	NSUInteger numStreamsToQueue = 1;
	if (settingsS.isSongCachingEnabled && settingsS.isNextSongCacheEnabled)
	{
		numStreamsToQueue = ISMSNumberOfStreamsToQueue;
	}
	
	if (self.handlerStack.count < numStreamsToQueue)
	{
		for (int i = 0; i < numStreamsToQueue; i++)
		{
			ISMSSong *aSong = [playlistS songForIndex:[playlistS indexForOffsetFromCurrentIndex:i]];
			if (aSong && !aSong.isVideo && ![self isSongInQueue:aSong] && ![self.lastTempCachedSong isEqualToSong:aSong] && !aSong.isFullyCached && !settingsS.isOfflineMode && ![cacheQueueManagerS.currentQueuedSong isEqualToSong:aSong])
			{
				// Queue the song for download
				[self queueStreamForSong:aSong isTempCache:!settingsS.isSongCachingEnabled isStartDownload:isStartDownload];
			}
		}
		
		DDLogVerbose(@"[ISMSStreamManager] fill stream queue, handlerStack: %@", self.handlerStack);
	}
}

- (void)fillStreamQueue
{
	[self fillStreamQueue:YES];
}

- (void)songCachingToggled
{
	if (settingsS.isSongCachingEnabled)
		[NSNotificationCenter addObserverOnMainThread:self selector:@selector(fillStreamQueue) name:ISMSNotification_SongPlaybackEnded];
	else
        [NSNotificationCenter removeObserverOnMainThread:self name:ISMSNotification_SongPlaybackEnded object:nil];
}

- (void)currentPlaylistIndexChanged
{
	// TODO: Fix this logic, it's wrong
	// Verify that the last song is not constantly retrying to connect, 
	// so the current song can download and play
	[self removeStreamForSong:playlistS.prevSong];
}

- (void)currentPlaylistOrderChanged
{
	ISMSSong *currentSong = playlistS.currentSong;
	ISMSSong *nextSong = playlistS.nextSong;
	NSMutableArray *songsToSkip = [NSMutableArray arrayWithCapacity:2];
	if (currentSong) [songsToSkip addObject:currentSong];
	if (nextSong) [songsToSkip addObject:nextSong];
	
	[self removeAllStreamsExceptForSongs:songsToSkip];
	[self fillStreamQueue:audioEngineS.player.isStarted];
}

#pragma mark - ISMSStreamHandler delegate

- (void)ISMSStreamHandlerStarted:(ISMSStreamHandler *)handler
{
	if (handler.isTempCache)
		self.lastTempCachedSong = nil;
}

- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler
{	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
    
    ISMSSong *currentSong = playlistS.currentSong;
	if ([handler.mySong isEqualToSong:playlistS.currentSong])
	{
		[audioEngineS startSong:currentSong atIndex:playlistS.currentIndex withOffsetInBytes:@0 orSeconds:@0];
		
		// Only for temp cached files
		if (handler.isTempCache)
		{
			// TODO: get rid of this ugly hack
            [EX2Dispatch runInMainThreadAfterDelay:1.0 block:^{
                //DLog(@"byteOffset: %llu   secondsOffset: %f", handler.byteOffset, handler.secondsOffset);
                audioEngineS.player.startByteOffset = (NSUInteger)handler.byteOffset;
                audioEngineS.player.startSecondsOffset = handler.secondsOffset;
            }];
		}
	}
	
	[self saveHandlerStack];
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error
{
	//DLog(@"stream handler failed: %@", handler);
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		//DLog(@"retrying stream handler");
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeHandler:) withObject:handler afterDelay:1.5];
		//[self startHandler:handler resume:YES];
	}
	else
	{
		//DLog(@"removing stream handler");
		//DLog(@"handlerStack: %@", self.handlerStack);
		// Tried max number of times so remove
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StreamHandlerSongFailed];
		[self removeStream:handler];
	}
}

- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler
{	
	BOOL isSuccess = YES;

	if (handler.totalBytesTransferred == 0)
	{
		// Not a trial issue, but no data was returned at all
        NSString *message = @"We asked for a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uh oh!"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];

		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
		isSuccess = NO;
	}
	else if (handler.totalBytesTransferred < 1000)
	{
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
	
	if (isSuccess)
	{
		//DLog(@"finished downloading song: %@", handler.mySong.title);
		
		// Mark song as cached
		if (!handler.isTempCache)
        {
            if ([cacheQueueManagerS isSongInQueue:handler.mySong])
            {
                //handler.mySong.isDownloaded = YES;
                [handler.mySong removeFromCacheQueueDbQueue];
            }
            
            DDLogVerbose(@"Marking isFullyCached = YES for %@", handler.mySong);
			handler.mySong.isFullyCached = YES;
		}
		
		// Update the last cached song
		self.lastCachedSong = handler.mySong;
		
		if (handler.isTempCache)
			self.lastTempCachedSong = handler.mySong;
		
		// Remove the handler from the stack
		[self removeStream:handler];
		
		// Start the next handler which is now the first object
		if ([self.handlerStack count] > 0)
		{
			ISMSStreamHandler *handler = [self.handlerStack firstObject];
			[self startHandler:handler];
		}
		
		// Keep the queue filled
		[self fillStreamQueue];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:handler.mySong.songId forKey:@"songId"];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StreamHandlerSongDownloaded 
													  userInfo:userInfo];
	}
}

#pragma mark - Singleton methods

- (void)delayedSetup
{
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		// Resume any handlers that were downloading when iSub closed
		if (handler.isDownloading && !handler.isTempCache)
		{
			DDLogVerbose(@"[ISMSStreamManager] resuming starting handler");
			[handler start:YES];
		}
	}
}

- (void)setup
{
	// Load the handler stack, it may have been full when iSub was closed
	[self loadHandlerStack];
	self.handlerStack = self.handlerStack ? self.handlerStack : [[NSMutableArray alloc] initWithCapacity:0];
	if ([self.handlerStack count] > 0)
	{
		if ([(ISMSStreamHandler *)[self.handlerStack firstObject] isTempCache])
		{
			[self removeAllStreams];
		}
		else
		{
			for (ISMSStreamHandler *handler in self.handlerStack)
			{
				// Resume any handlers that were downloading when iSub closed
				if (handler.isDownloading && !handler.isTempCache)
				{
					[handler start:YES];
				}
			}
		}
	}
	
	self.lastCachedSong = nil;
	self.lyricsDAO = [[SUSLyricsDAO alloc] initWithDelegate:nil]; 
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(songCachingToggled) name:ISMSNotification_SongCachingEnabled];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(songCachingToggled) name:ISMSNotification_SongCachingDisabled];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(currentPlaylistIndexChanged) name:ISMSNotification_CurrentPlaylistIndexChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_RepeatModeChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_CurrentPlaylistOrderChanged];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(currentPlaylistOrderChanged) name:ISMSNotification_CurrentPlaylistShuffleToggled];
    if (settingsS.isSongCachingEnabled)
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(fillStreamQueue) name:ISMSNotification_SongPlaybackEnded];
}

+ (instancetype)sharedInstance
{
    static ISMSStreamManager *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}


@end
