//
//  ISMSStreamHandler.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSURLConnectionStreamHandler.h"
#import "NSError+ISMSError.h"
#import "DatabaseSingleton.h"
#import "NSMutableURLRequest+SUS.h"

LOG_LEVEL_ISUB_DEFAULT

//#define kMinKiloBytesToStartPlayback 250
//#define kMinBytesToStartPlayback ((unsigned long long)(1024 * kMinKiloBytesToStartPlayback)) // Number of bytes to wait before activating the player
//#define kMinBytesToStartLimiting ((unsigned long long)(1024 * 1024))	// Start throttling bandwidth after 1 MB downloaded for 160kbps files (adjusted accordingly by bitrate)

// Logging
#define isProgressLoggingEnabled 0
#define isThrottleLoggingEnabled 1
#define isSpeedLoggingEnabled 0

#define ISMSDownloadTimeoutTimer @"ISMSDownloadTimeoutTimer"

@implementation ISMSURLConnectionStreamHandler

// Create the request and start the connection in loadingThread
- (void)start:(BOOL)resume
{
	if (!resume)
	{
		// Clear temp cache if this is a temp file
		if (self.isTempCache)
		{
			[cacheS clearTempCache];
		}
	}
	
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler start:%@ for: %@", NSStringFromBOOL(resume), self.mySong.title);
	
	self.totalBytesTransferred = 0;
	self.bytesTransferred = 0;
	self.byteOffset = 0;
	
	// Create the file handle
	self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	
	if (self.fileHandle)
	{
		if (resume)
		{
			// File exists so seek to end
			self.totalBytesTransferred = [self.fileHandle seekToEndOfFile];
			self.byteOffset += self.totalBytesTransferred;
		}
		else
		{
			// File exists so remove it
			[self.fileHandle closeFile];
			self.fileHandle = nil;
			[[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
		}
	}
	
    if (!resume)
	{
		// Create the file
		self.totalBytesTransferred = 0;
		[[NSFileManager defaultManager] createFileAtPath:self.filePath contents:[NSData data] attributes:nil];
		self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	}
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.mySong.songId), @"id", nil];
    [parameters setObject:@"true" forKey:@"estimateContentLength"];
    
    if (self.maxBitrateSetting == NSIntegerMax)
    {
        self.maxBitrateSetting = settingsS.currentMaxBitrate;
    }
    
    if (self.maxBitrateSetting != 0)
    {
        NSString *maxBitRate = [[NSString alloc] initWithFormat:@"%ld", (long)self.maxBitrateSetting];
        [parameters setObject:n2N(maxBitRate) forKey:@"maxBitRate"];
    }
    self.request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:(NSUInteger)self.byteOffset];
    
	if (!self.request)
	{
		[self startConnectionInternalFailure];
		return;
	}

	self.loadingThread = [[NSThread alloc] initWithTarget:self selector:@selector(startConnection) object:nil];
	
	self.bitrate = self.mySong.estimatedBitrate;

	NSDate *now = [[NSDate alloc] init];
	[self.loadingThread.threadDictionary setObject:now forKey:@"throttlingDate"];
		
	if ([self.mySong isEqualToSong:[playlistS currentSong]])
	{
		self.isCurrentSong = YES;
	}
		
	[self.loadingThread start];
}

- (void)connectionTimedOut
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler connectionTimedOut for %@", self.mySong);
	
	[self cancel];
	[self didFailInternal:nil];
}

// loadingThread entry point
- (void)startConnection
{
	@autoreleasepool 
	{
		self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
		if (self.connection)
		{
			self.isDownloading = YES;
			[self performSelectorOnMainThread:@selector(startConnectionInternalSuccess) withObject:nil waitUntilDone:NO];
			
			//DLog(@"Stream Handler Connection Starting for %@", self.mySong.title);
			
			/*[EX2Dispatch timerInMainQueueAfterDelay:30. withName:ISMSDownloadTimeoutTimer performBlock:^{
				[self cancel];
				[self didFailInternal:nil];
			}];*/
			
			[self performSelectorOnMainThread:@selector(startTimeOutTimer) withObject:nil waitUntilDone:NO];
			
			//DLog(@"Stream handler download starting for %@", mySong);
			CFRunLoopRun();
			//DLog(@"Stream handler runloop finished for %@", mySong);
		}
		else
		{
			[self performSelectorOnMainThread:@selector(startConnectionInternalFailure) withObject:nil waitUntilDone:NO];
		}
	}
}

- (void)startConnectionInternalSuccess
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler startConnectionInternalSuccess for %@", self.mySong);

	if (!self.isTempCache)
		self.mySong.isPartiallyCached = YES;
	
#ifdef IOS
	[EX2NetworkIndicator usingNetwork];
#endif
    
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStarted:)])
		[self.delegate ISMSStreamHandlerStarted:self];
}

- (void)startConnectionInternalFailure
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] start connection failed");
	NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
}

// Cancel the download and stop the run loop in loadingThread
- (void)cancel
{
	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
	
#ifdef IOS
	if (self.isDownloading)
		[EX2NetworkIndicator doneUsingNetwork];
#endif

	self.isDownloading = NO;
	self.isCanceled = YES;
	
	// Pop out of infinite loop if partially pre-cached
	self.partialPrecacheSleep = NO;
	
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler request canceled for %@", self.mySong);
	[self.connection cancel]; 
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
		
	[self performSelector:@selector(cancelRunLoop) onThread:self.loadingThread withObject:nil waitUntilDone:NO];	
}

// Stop the current run loop
- (void)cancelRunLoop
{
	CFRunLoopStop(CFRunLoopGetCurrent());
}


#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)theConnection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler canAuthenticateAgainstProtectionSpace for %@", self.mySong);

	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)theConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler didReceiveAuthenticationChallenge for %@", self.mySong);

	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler didReceiveResponse for %@", self.mySong);

	if ([response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
		//DLog(@"allHeaderFields: %@", [httpResponse allHeaderFields]);
		//DLog(@"statusCode: %i - %@", [httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
		
		if ([httpResponse statusCode] >= 500)
		{
			// This is a failure, cancel the connection and call the didFail delegate method
			[self.connection cancel];
			[self connection:self.connection didFailWithError:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer]];
		}
		else
		{
			if (self.contentLength == ULLONG_MAX)
			{
				// Set the content length if it isn't set already, only set the first connection, not on retries
				NSString *contentLengthString = [[httpResponse allHeaderFields] objectForKey:@"Content-Length"];
				if (contentLengthString)
				{
					self.contentLength = [contentLengthString longLongValue];
				}
			}
		}
	}
	
	self.bytesTransferred = 0;
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{	
	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
		
	if (self.isCanceled)
		return;
	
	if (isSpeedLoggingEnabled)
	{
		if (!self.speedLoggingDate)
		{
			self.speedLoggingDate = [NSDate date];
			self.speedLoggingLastSize = self.totalBytesTransferred;
		}
	}
	
	NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
	NSDate *throttlingDate = [threadDict objectForKey:@"throttlingDate"];
	NSUInteger dataLength = [incrementalData length];
	
	self.totalBytesTransferred += dataLength;
	self.bytesTransferred += dataLength;
	
	if (self.fileHandle)
    {
        // Save the data to the file
        @try
        {
            [self.fileHandle writeData:incrementalData];
        }
        @catch (NSException *exception)
        {
			//DLog(@"Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
            [EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self cancel]; }];
        }
		
		// Notify delegate if enough bytes received to start playback
        if (!self.isDelegateNotifiedToStartPlayback && self.totalBytesTransferred >= ISMSMinBytesToStartPlayback(self.bitrate))
        {
			//DLog(@"telling player to start, min bytes: %u, total bytes: %llu, bitrate: %u", ISMSMinBytesToStartPlayback(self.bitrate), self.totalBytesTransferred, self.bitrate);
            self.isDelegateNotifiedToStartPlayback = YES;
            //DLog(@"player told to start playback");
            [EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self startPlaybackInternal]; }];
        }
		
		// Log progress
		if (isProgressLoggingEnabled)
			DDLogInfo(@"[ISMSURLConnectionStreamHandler] downloadedLengthA:  %llu   bytesRead: %lu", self.totalBytesTransferred, (unsigned long)dataLength);
		
		// If near beginning of file, don't throttle
		if (self.totalBytesTransferred < ISMSMinBytesToStartLimiting(self.bitrate))
		{
			NSDate *now = [[NSDate alloc] init];
			[threadDict setObject:now forKey:@"throttlingDate"];
			self.bytesTransferred = 0;		
		}
		
        if (self.isEnableRateLimiting)
        {
            // Check if we should throttle
            NSDate *now = [[NSDate alloc] init];
            NSTimeInterval intervalSinceLastThrottle = [now timeIntervalSinceDate:throttlingDate];
            if (intervalSinceLastThrottle > ISMSThrottleTimeInterval && self.totalBytesTransferred > ISMSMinBytesToStartLimiting(self.bitrate))
            {
                NSTimeInterval delay = 0.0;
                
#ifdef IOS
                double maxBytesPerInterval = [self.class maxBytesPerIntervalForBitrate:(double)self.bitrate is3G:![LibSub isWifi]];
#else
                double maxBytesPerInterval = [self.class maxBytesPerIntervalForBitrate:(double)self.bitrate is3G:NO];
#endif
                double numberOfIntervals = intervalSinceLastThrottle / ISMSThrottleTimeInterval;
                double maxBytesPerTotalInterval = maxBytesPerInterval * numberOfIntervals;
                
                if (self.bytesTransferred > maxBytesPerTotalInterval)
                {
                    double speedDifferenceFactor = (double)self.bytesTransferred / maxBytesPerTotalInterval;
                    delay = (speedDifferenceFactor * intervalSinceLastThrottle) - intervalSinceLastThrottle;
                    
                    if (isThrottleLoggingEnabled)
                        DDLogInfo(@"[ISMSURLConnectionStreamHandler] Pausing for %f  interval: %f  bytesTransferred: %llu maxBytes: %f", delay, intervalSinceLastThrottle, self.bytesTransferred, maxBytesPerTotalInterval);
                    
                    self.bytesTransferred = 0;
                }
                
                [NSThread sleepForTimeInterval:delay];
                
                if (self.isCanceled)
                    return;
                
                NSDate *newThrottlingDate = [[NSDate alloc] init];
                [threadDict setObject:newThrottlingDate forKey:@"throttlingDate"];
            }
        }
		
		// Handle partial pre-cache next song
		if (!self.isCurrentSong && !self.isTempCache && settingsS.isPartialCacheNextSong && self.partialPrecacheSleep)
		{
			NSUInteger partialPrecacheSize = ISMSNumBytesToPartialPreCache(self.mySong.estimatedBitrate);
			if (self.totalBytesTransferred >= partialPrecacheSize)
			{
				[self performSelectorOnMainThread:@selector(partialPrecachePausedInternal) withObject:nil waitUntilDone:NO];
				while (self.partialPrecacheSleep && !self.tempBreakPartialPrecache)
				{
					[NSThread sleepForTimeInterval:0.1];
				}
				self.tempBreakPartialPrecache = NO;
				[self performSelectorOnMainThread:@selector(partialPrecacheUnpausedInternal) withObject:nil waitUntilDone:NO];
			}
		}
	}
	else
	{
		DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler did receive data but encryptor was nil for %@", self.mySong);

		if (!self.isCanceled)
		{
			// There is no file handle for some reason, cancel the connection
			[self.connection cancel];
			[self connection:self.connection didFailWithError:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer]];
		}
	}
	
#if isSpeedLoggingEnabled
	if (isSpeedLoggingEnabled)
	{
		NSTimeInterval speedInteval = [[NSDate date] timeIntervalSinceDate:self.speedLoggingDate];
		
		// Check every 10 seconds
		if (speedInteval >= 10.0)
		{
			unsigned long long transferredSinceLastCheck = self.totalBytesTransferred - self.speedLoggingLastSize;
			
			double speedInBytes = (double)transferredSinceLastCheck / speedInteval;
			double speedInKbytes = speedInBytes / 1024.;
			DDLogInfo(@"[ISMSURLConnectionStreamHandler] rate: %f  speedInterval: %f  transferredSinceLastCheck: %llu", speedInKbytes, speedInteval, transferredSinceLastCheck);
			
			self.speedLoggingLastSize = self.totalBytesTransferred;
			self.speedLoggingDate = [NSDate date];
		}
	}
#endif
	
	/*[EX2Dispatch timerInMainQueueAfterDelay:30. withName:ISMSDownloadTimeoutTimer performBlock:^{
		[self cancel];
		[self didFailInternal:nil];
	}];*/
	[self performSelectorOnMainThread:@selector(startTimeOutTimer) withObject:nil waitUntilDone:NO];
}

// Main Thread
- (void)partialPrecachePausedInternal
{
	self.isPartialPrecacheSleeping = YES;

#ifdef IOS
	if (!self.isCanceled)
		[EX2NetworkIndicator doneUsingNetwork];
#endif
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecachePaused:)])
		[self.delegate ISMSStreamHandlerPartialPrecachePaused:self];
}

// Main Thread
- (void)partialPrecacheUnpausedInternal
{
	self.isPartialPrecacheSleeping = NO;
	
#ifdef IOS
	if (!self.isCanceled)
		[EX2NetworkIndicator usingNetwork];
#endif
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecacheUnpaused:)])
		[self.delegate ISMSStreamHandlerPartialPrecacheUnpaused:self];
}

// Main Thread
- (void)startPlaybackInternal
{
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStartPlayback:)])
		[self.delegate ISMSStreamHandlerStartPlayback:self];
}

// loadingThread
- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
	
	DDLogError(@"[ISMSURLConnectionStreamHandler] Connection Failed for %@", self.mySong.title);
	DDLogError(@"[ISMSURLConnectionStreamHandler] error domain: %@  code: %ld description: %@", error.domain, (long)error.code, error.description);
	
	// Perform these operations on the main thread
	[self performSelectorOnMainThread:@selector(didFailInternal:) withObject:error waitUntilDone:YES];
	
	// Stop the run loop so the thread can die
	[self cancelRunLoop];
}	

// Main Thread
- (void)didFailInternal:(NSError *)error
{
	DDLogVerbose(@"[ISMSURLConnectionStreamHandler] Stream handler didFailInternal for %@", self.mySong);

	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
	
	self.isDownloading = NO;
	
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
#ifdef IOS
	[EX2NetworkIndicator doneUsingNetwork];
#endif
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
}

// loadingThread
- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
	
	//DLog(@"localSize: %llu   contentLength: %llu", mySong.localFileSize, self.contentLength);
		
	// Check to see if we're at the contentLength (to allow some leeway for contentLength estimation of transcoded songs
	if (self.contentLength != ULLONG_MAX && self.mySong.localFileSize < self.contentLength && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures)
	{
		self.numberOfContentLengthFailures++;
		// This is a failed connection that didn't call didFailInternal for some reason, so call didFailWithError
		[self connection:theConnection didFailWithError:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer]];
	}
	else 
	{
		// Make sure the player is told to start
		if (!self.isDelegateNotifiedToStartPlayback)
		{
			self.isDelegateNotifiedToStartPlayback = YES;
			[EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{ [self startPlaybackInternal]; }];
		}
		
		// Perform these operations on the main thread
		[EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{ [self didFinishLoadingInternal]; }];
		
		// Stop the run loop so the thread can die
		[self cancelRunLoop];
	}
}

// Main Thread
- (void)didFinishLoadingInternal
{
	[self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
	
	self.isDownloading = NO;
	
	self.connection = nil;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
#ifdef IOS
	[EX2NetworkIndicator doneUsingNetwork];
#endif
	
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFinished:)])
		[self.delegate ISMSStreamHandlerConnectionFinished:self];
}

@end
