//
//  ISMSCFNetworkStreamHandler.m
//  Anghami
//
//  Created by Ben Baron on 7/4/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSCFNetworkStreamHandler.h"
#import "BassGaplessPlayer.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@interface ISMSCFNetworkStreamHandler ()
{
	UInt8		_buffer[16 * 1024];				//	Create a 16K buffer
	CFIndex		_bytesRead;
	CFReadStreamRef _readStreamRef;
	NSTimeInterval _lastThrottle;
}
@property (nonatomic) BOOL isPrecacheSleeping;
@property (strong) ISMSCFNetworkStreamHandler *selfRef;
- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type;
@end

@implementation ISMSCFNetworkStreamHandler

// Logging
#define isProgressLoggingEnabled 0
#define isThrottleLoggingEnabled 1
#define isSpeedLoggingEnabled 1

LOG_LEVEL_ISUB_DEFAULT

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)start:(BOOL)resume
{    
    if (!self.filePath)
    {
        DDLogError(@"[ISMSCFNetworkStreamHandler] start: called but filePath is nil, so bailing");
        return;
    }
    
    if (_readStreamRef)
        [self terminateDownload];
	
    if (!self.selfRef)
        self.selfRef = self;
	
	//DLog(@"downloadCFNetA url: %@", [url absoluteString]);
	
	/*if (throttlingDate)
	 [throttlingDate release];
	 throttlingDate = nil;
	 bytesTransferred = 0;*/
	
    self.contentLength = ULLONG_MAX;
	self.totalBytesTransferred = 0;
	self.bytesTransferred = 0;
    
    //if (!resume)
    //    self.byteOffset = 0;
    	
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
        // Clear temp cache if this is a temp file
		if (self.isTempCache)
		{
			[cacheS clearTempCache];
		}
        
		// Create the file
		self.totalBytesTransferred = 0;
		[[NSFileManager defaultManager] createFileAtPath:self.filePath contents:[NSData data] attributes:nil];
		self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
	}
    
    // Mark the new file as no backup
#ifdef IOS
    if (!settingsS.isBackupCacheEnabled)
    {
        if (![[NSURL fileURLWithPath:self.filePath] addSkipBackupAttribute])
        {
            DDLogError(@"Failed to set the no backup flag for %@", self.filePath);
        }
    }
#endif
	
	self.bitrate = self.mySong.estimatedBitrate;
    
    if (self.maxBitrateSetting == NSIntegerMax)
    {
        self.maxBitrateSetting = settingsS.currentMaxBitrate;
    }
	
    NSURLRequest *request;
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.mySong.songId), @"id", nil];
        
        // Causes a problem with some files in Subsonic, it will cut them off halfway
		//[parameters setObject:@"true" forKey:@"estimateContentLength"];
		
		if (self.maxBitrateSetting != 0)
		{
			NSString *maxBitRate = [[NSString alloc] initWithFormat:@"%ld", (long)self.maxBitrateSetting];
			[parameters setObject:n2N(maxBitRate) forKey:@"maxBitRate"];
		}
		request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:self.byteOffset];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:self.mySong.songId forKey:@"id"];
        
        if (self.bitrate < self.maxBitrateSetting || self.maxBitrateSetting == 0)
        {
            request = [NSMutableURLRequest requestWithPMSAction:@"stream" parameters:parameters byteOffset:self.byteOffset];
        }
        
        else
        {
            [parameters setObject:@"OPUS" forKey:@"transType"];

            NSString *transQuality;
            switch (self.maxBitrateSetting)
            {
                case 64: transQuality = @"Low"; break;
                case 96: transQuality = @"Medium"; break;
                case 128: transQuality = @"High"; break;
                default: transQuality = [NSString stringWithFormat:@"%li", (long)self.maxBitrateSetting];
            }
            [parameters setObject:transQuality forKey:@"transQuality"];
            [parameters setObject:@"true" forKey:@"estimateContentLength"];
            
            request = [NSMutableURLRequest requestWithPMSAction:@"transcode" parameters:parameters byteOffset:self.byteOffset];
        }
	}
    
	if (!request)
	{
		[self downloadFailed];
		return;
	}
	
	CFStreamClientContext ctxt = {0, (__bridge void*)self, NULL, NULL, NULL};
        
    // Make sure the request URL is not nil, or we will have a strange looking SIGTRAP crash with a misleading stack trace
    if (!request.URL)
    {
        [self bail:NULL];
        return;
    }
	
	// Create the request
	CFHTTPMessageRef messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (__bridge CFStringRef)request.HTTPMethod, (__bridge CFURLRef)request.URL, kCFHTTPVersion1_1);
	if (messageRef == NULL) 
		[self bail:NULL];
    
    // Set the URL
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("HOST"), (__bridge CFStringRef)[request.URL host]);
	
    // Set the request type
    if ([request.HTTPMethod isEqualToString:@"POST"])
    {
        CFHTTPMessageSetBody(messageRef, (__bridge CFDataRef)request.HTTPBody);
    }
    
    // Set all the headers
    if (request.allHTTPHeaderFields.count > 0)
    {
        for (NSString *key in request.allHTTPHeaderFields.allKeys)
        {
            NSString *value = [request.allHTTPHeaderFields objectForKey:key];
            if (value)
                CFHTTPMessageSetHeaderFieldValue(messageRef, (__bridge CFStringRef)key, (__bridge CFStringRef)value);
        }
    }
	
	//DDLogInfo(@"[ISMSCFNetworkStreamHandler] url: %@\nheaders: %@\nbody: %@\nsong: %@", request.URL.absoluteString, request.allHTTPHeaderFields, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding], self.mySong);
	
	// Create the stream for the request.
	_readStreamRef = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, messageRef);
	if (_readStreamRef == NULL) [self bail:messageRef];
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125")); 
	
	// Enable stream redirection
	if (CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		[self bail:messageRef];
	
	// Handle SSL connections
	if([[request.URL absoluteString] rangeOfString:@"https"].location != NSNotFound)
	{
		NSDictionary *sslSettings =
		[NSDictionary dictionaryWithObjectsAndKeys:
		 (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
		 @NO, kCFStreamSSLValidatesCertificateChain,
		 [NSNull null], kCFStreamSSLPeerName,
		 nil];
		
		CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)sslSettings);
	}
	
	// Handle proxy
	CFDictionaryRef proxyDict = CFNetworkCopySystemProxySettings();
	CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertyHTTPProxy, proxyDict);
    CFRelease(proxyDict);
	
	// Set the client notifier
	if (CFReadStreamSetClient(_readStreamRef, kNetworkEvents, ReadStreamClientCallBack, &ctxt) == false)
		[self bail:messageRef];
	
	if ([self.mySong isEqualToSong:[playlistS currentSong]])
	{
		self.isCurrentSong = YES;
	}
	
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    [self startTimeOutTimer];
	
	self.isDownloading = YES;
    
#ifdef IOS
	[EX2NetworkIndicator usingNetwork];
#endif
    
	// Start the HTTP connection
	if (CFReadStreamOpen(_readStreamRef) == false)
		[self bail:messageRef];
	
	//DLog(@"--- STARTING HTTP CONNECTION");
	
	if (messageRef != NULL) CFRelease(messageRef);
	return;
}

- (void)bail:(CFHTTPMessageRef)messageRef
{
    if (messageRef != NULL) 
    	CFRelease(messageRef);
	[self terminateDownload];
}

- (void)cancel
{    
    if (self.isCanceled)
        return;
    
	DDLogVerbose(@"[ISMSCFNetworkStreamHandler] Stream handler request canceled for %@", self.mySong);
	
    self.isCanceled = YES;
    
    if (!self.isDownloading)
        return;
    
	self.isDownloading = NO;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
    [self terminateDownload];
}

- (void)connectionTimedOut
{
	DDLogVerbose(@"[ISMSCFNetworkStreamHandler] Stream handler connectionTimedOut for %@", self.mySong);
    
	[self downloadFailed];
}

- (void)terminateDownload
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(continueDownload) object:nil];
	
	[EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^
	 {
         [self stopTimeOutTimer];
         
#ifdef IOS
		 if (self.isDownloading)
			 [EX2NetworkIndicator doneUsingNetwork];
#endif
		 
		 self.isDownloading = NO;
		 
		 if (_readStreamRef == NULL)
		 {
			 //DLog(@"------------------------------ stream is nil so returning");
			 return;
		 }
		 //DLog(@"------------------------------ stream is not nil so closing the stream");
		 
		 //***	ALWAYS set the stream client (notifier) to NULL if you are releasing it
		 //	otherwise your notifier may be called after you released the stream leaving you with a 
		 //	bogus stream within your notifier.
		 //DLog(@"canceling stream: %@", readStreamRef);
		 CFReadStreamSetClient(_readStreamRef, kCFStreamEventNone, NULL, NULL);
		 CFReadStreamUnscheduleFromRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
		 CFReadStreamClose(_readStreamRef);
		 CFRelease(_readStreamRef);
		 
		 _readStreamRef = NULL;
         
         self.selfRef = nil;
	 }];
}

static void ReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
	@autoreleasepool 
	{
		[(__bridge ISMSCFNetworkStreamHandler *)clientCallBackInfo readStreamClientCallBack:stream type:type];
	}
}

- (void)continueDownload
{
	if (self.isCanceled)
		return;
	
	if (_readStreamRef != NULL)
	{
		// Schedule the stream
		_lastThrottle = CFAbsoluteTimeGetCurrent();
		CFReadStreamScheduleWithRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	}
}

- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type
{
	if (!self.isDownloading)
		return;
    	
	if (type == kCFStreamEventOpenCompleted)
	{
        // Reset the time out timer since the connection responded
        [self startTimeOutTimer];
        
        self.startDate = [NSDate date];
        self.speedLoggingDate = nil;
        
		DDLogCVerbose(@"[ISMSCFNetworkStreamHandler] Stream handler: kCFStreamEventOpenCompleted occured for %@", self.mySong);
		if (!self.isTempCache)
			self.mySong.isPartiallyCached = YES;
		
		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStarted:)])
			[self.delegate ISMSStreamHandlerStarted:self];
	}
	else if (type == kCFStreamEventHasBytesAvailable)
	{
        if (!self.speedLoggingDate)
        {
            self.speedLoggingDate = [NSDate date];
            self.speedLoggingLastSize = self.totalBytesTransferred;
        }
        
		_bytesRead = CFReadStreamRead(stream, _buffer, sizeof(_buffer));
				
		if (_bytesRead > 0)	// If zero bytes were read, wait for the EOF to come.
		{
            // Reset the time out timer since some bytes were received
            [self startTimeOutTimer];
            
            if (self.fileHandle)
            {
                // Save the data to the file
                @try
                {
                    [self.fileHandle writeData:[NSData dataWithBytesNoCopy:_buffer length:_bytesRead freeWhenDone:NO]];
                }
                @catch (NSException *exception)
                {
                    DDLogCError(@"[ISMSCFNetworkStreamHandler] Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
					
					if (cacheS.freeSpace <= BytesFromMiB(25))
					{
						/*[EX2Dispatch runInMainThread:^
						 {
							 // Space has run out, so show the message
							 [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot stream any more music. Please free some space and try again", @"Stream manager, device out of space message")];
						 }];*/
					}
					
					[self cancel];
                }
				
				self.totalBytesTransferred += _bytesRead;
				self.bytesTransferred += _bytesRead;
                
                //DLog(@"downloading song, bytes transferred ")
				
				//if (isProgressLoggingEnabled)
				//	//DLog(@"downloadedLengthA:  %lu   bytesRead: %ld", [musicControlsRef downloadedLengthA], bytesRead);
				
				// Notify delegate if enough bytes received to start playback
                NSUInteger bytesPerSec = self.totalBytesTransferred / [[NSDate date] timeIntervalSinceDate:self.startDate];
				if (!self.isDelegateNotifiedToStartPlayback && self.totalBytesTransferred >= [self.class minBytesToStartPlaybackForKiloBitrate:self.bitrate speedInBytesPerSec:bytesPerSec])
				{
					DDLogCVerbose(@"[ISMSCFNetworkStreamHandler] telling player to start, min bytes: %lu, total bytes: %llu, bitrate: %lu, bytesPerSec: %lu  song: %@", (unsigned long)ISMSMinBytesToStartPlayback(self.bitrate), self.totalBytesTransferred, (unsigned long)self.bitrate, (unsigned long)bytesPerSec, self.mySong);
					self.isDelegateNotifiedToStartPlayback = YES;
					
					if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStartPlayback:)])
						[self.delegate ISMSStreamHandlerStartPlayback:self];
				}
				
                // We're no longer ever setting this to true because Subsonic kills rate limited connections now
                if (self.isEnableRateLimiting)
                {
                    // Check if we should throttle
                    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
                    NSTimeInterval intervalSinceLastThrottle = now - _lastThrottle;
                    if (intervalSinceLastThrottle > ISMSThrottleTimeInterval && self.totalBytesTransferred > ISMSMinBytesToStartLimiting(self.bitrate))
                    {
                        NSTimeInterval delay = 0.0;
                        
#ifdef IOS
                        BOOL isWifi = [LibSub isWifi] || self.delegate == cacheQueueManagerS;
#else
                        BOOL isWifi = YES;
#endif
                        double maxBytesPerInterval = [self.class maxBytesPerIntervalForBitrate:(double)self.bitrate is3G:!isWifi];
                        double numberOfIntervals = intervalSinceLastThrottle / ISMSThrottleTimeInterval;
                        double maxBytesPerTotalInterval = maxBytesPerInterval * numberOfIntervals;
                        
                        if (self.bytesTransferred > maxBytesPerTotalInterval)
                        {
                            double speedDifferenceFactor = (double)self.bytesTransferred / maxBytesPerTotalInterval;
                            delay = (speedDifferenceFactor * intervalSinceLastThrottle) - intervalSinceLastThrottle;
                            
                            if (isThrottleLoggingEnabled)
                                DDLogCInfo(@"[ISMSCFNetworkStreamHandler] Pausing for %f  interval: %f  bytesTransferred: %llu maxBytes: %f  song: %@", delay, intervalSinceLastThrottle, self.bytesTransferred, maxBytesPerTotalInterval, self.mySong);
                            
                            self.bytesTransferred = 0;
                        }
                        
                        // Pause by unscheduling from the runloop
                        CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
                        
                        // Continue after the delay
                        [self performSelector:@selector(continueDownload) withObject:nil afterDelay:delay];
                    }
                }
                
                // Get the download speed, check every 6 seconds
                NSTimeInterval speedInteval = [[NSDate date] timeIntervalSinceDate:self.speedLoggingDate];
                if (speedInteval >= 6.0)
                {
                    unsigned long long transferredSinceLastCheck = self.totalBytesTransferred - self.speedLoggingLastSize;
                    
                    double speedInBytes = (double)transferredSinceLastCheck / speedInteval;
                    self.recentDownloadSpeedInBytesPerSec = speedInBytes;
                    
#if isSpeedLoggingEnabled
                    double speedInKbytes = speedInBytes / 1024.;
                    DDLogInfo(@"[ISMSURLConnectionStreamHandler] rate: %f  speedInterval: %f  transferredSinceLastCheck: %llu  song: %@", speedInKbytes, speedInteval, transferredSinceLastCheck, self.mySong);
#endif
                    
                    self.speedLoggingLastSize = self.totalBytesTransferred;
                    self.speedLoggingDate = [NSDate date];
                }
                
                // Handle partial pre-cache next song
                if (!self.isCurrentSong && !self.isTempCache && settingsS.isPartialCacheNextSong && self.partialPrecacheSleep)
                {
                    NSUInteger partialPrecacheSize = ISMSNumBytesToPartialPreCache(self.mySong.estimatedBitrate);
                    if (self.totalBytesTransferred >= partialPrecacheSize)
                    {
                        // First verify that the stream can be opened
                        if (audioEngineS.player)
                        {
                            if ([audioEngineS.player testStreamForSong:self.mySong])
                            {
                                // We're sleeping, so clear the speed logging data as it won't be accurate after the sleep
                                self.speedLoggingDate = nil;
                                self.speedLoggingLastSize = 0;
                                self.recentDownloadSpeedInBytesPerSec = 0;
                                
                                // The stream worked, so go ahead and pause the download
                                self.isPrecacheSleeping = YES;
                                CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
                                if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecachePaused:)])
                                {
                                    [self.delegate ISMSStreamHandlerPartialPrecachePaused:self];
                                }
                            }
                            else
                            {
                                self.secondsToPartialPrecache += 10;
                            }
                        }
                    }
                }
			}
			else
			{
				DDLogCError(@"[ISMSCFNetworkStreamHandler] Stream handler: An error occured in the download for %@", self.mySong);
				[self downloadFailed];
			}
		}
		else if (_bytesRead < 0)		// Less than zero is an error
		{
			DDLogCError(@"[ISMSCFNetworkStreamHandler] Stream handler: An occured in the download bytesRead < 0 for %@", self.mySong);
			[self downloadFailed];
		}
		else	//	0 assume we are done with the stream
		{
			DDLogCVerbose(@"[ISMSCFNetworkStreamHandler] Stream handler: bytesRead == 0 occured in the download, but we're continuing for %@", self.mySong);
			//[self downloadDone];
		}
	}
	else if (type == kCFStreamEventEndEncountered)
	{
		DDLogCVerbose(@"[ISMSCFNetworkStreamHandler] Stream handler: An kCFStreamEventEndEncountered occured in the download, download is done for %@", self.mySong);
		[self downloadDone];
	}
	else if (type == kCFStreamEventErrorOccurred)
	{
		DDLogCError(@"[ISMSCFNetworkStreamHandler] Stream handler: An kCFStreamEventErrorOccurred occured in the download for %@", self.mySong);
		[self downloadFailed];
	}
}

- (void)downloadFailed
{
	self.isDownloading = NO;
	
	// Close the file handle
	[self.fileHandle closeFile];
	self.fileHandle = nil;
		
	if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
		[self.delegate ISMSStreamHandlerConnectionFailed:self withError:nil];
	
	[self terminateDownload];
}

- (void)downloadDone
{
    NSDate *start = [NSDate date];
    
	// Get the response header
	if (_readStreamRef != NULL)
	{
        CFHTTPMessageRef myResponse = (CFHTTPMessageRef)CFReadStreamCopyProperty(_readStreamRef, kCFStreamPropertyHTTPResponseHeader);
        if (myResponse != NULL)
        {
            // Log the status code
            DDLogInfo(@"[ISMSCFNetworkStreamHandler] http response status: %lu", CFHTTPMessageGetResponseStatusCode(myResponse));
            
            // Get the content length (must grab the dict because using CFHTTPMessageCopyHeaderFieldValue if the value doesn't exist will cause an EXC_BAD_ACCESS
            CFDictionaryRef headerDict = CFHTTPMessageCopyAllHeaderFields(myResponse);
            if (headerDict != NULL)
            {
                if (CFDictionaryContainsKey(headerDict, CFSTR("Content-Length")))
                {
                    CFStringRef length = CFHTTPMessageCopyHeaderFieldValue(myResponse, CFSTR("Content-Length"));
                    if (length != NULL)
                    {
                        self.contentLength = [(__bridge NSString *)length longLongValue];
                        CFRelease(length);
                    }
                }
                
                //DDLogInfo(@"[ISMSCFNetworkStreamHandler] http response headers: %@", headerDict);
                CFRelease(headerDict);
            }
            CFRelease(myResponse);
        }
	}
    			  
	DDLogCInfo(@"[ISMSCFNetworkStreamHandler] Connection Finished for %@  file size: %llu   contentLength: %llu", self.mySong.title, self.mySong.localFileSize, self.contentLength);
	
	self.isDownloading = NO;
    
    // Close the file handle in a background thread to prevent blocking the main thread
    [EX2Dispatch runInBackgroundAsync:^{
        __strong NSFileHandle *handle = self.fileHandle;
        [handle closeFile];
        handle = nil;
    }];
    	
	if (self.contentLength != ULLONG_MAX && self.mySong.localFileSize < self.contentLength && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures)
	{
		DDLogCInfo(@"[ISMSCFNetworkStreamHandler] Connection Failed because not enough bytes were downloaed for %@", self.mySong.title);

		// This is a failed download, it didn't download enough
		self.numberOfContentLengthFailures++;
		
		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
			[self.delegate ISMSStreamHandlerConnectionFailed:self withError:nil];
	}
	else
	{
		DDLogCInfo(@"[ISMSCFNetworkStreamHandler] Connection was successful because the file size matches the content length header for %@", self.mySong.title);

		if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFinished:)])
			[self.delegate ISMSStreamHandlerConnectionFinished:self];
	}
    
    ALog(@"Download done took %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
    
    [self terminateDownload];
}

- (void)setPartialPrecacheSleep:(BOOL)partialPrecacheSleep
{
    [super setPartialPrecacheSleep:partialPrecacheSleep];
    if (!partialPrecacheSleep && self.isPartialPrecacheSleeping)
    {
        self.isPartialPrecacheSleeping = NO;
        [self continueDownload];
        
        if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecacheUnpaused:)])
        {
            [self.delegate ISMSStreamHandlerPartialPrecacheUnpaused:self];
        }
    }
}

@end
