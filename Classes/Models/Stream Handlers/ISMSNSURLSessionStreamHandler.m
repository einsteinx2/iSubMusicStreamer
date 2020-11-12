//
//  ISMSNSURLSessionStreamHandler.m
//  iSub
//
//  Created by Benjamin Baron on 11/12/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSNSURLSessionStreamHandler.h"
#import "NSError+ISMSError.h"
#import "DatabaseSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "CacheSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "LibSub.h"

LOG_LEVEL_ISUB_DEFAULT

// Logging
#define isProgressLoggingEnabled 0
#define isThrottleLoggingEnabled 1
#define isSpeedLoggingEnabled 0

#define ISMSDownloadTimeoutTimer @"ISMSDownloadTimeoutTimer"

@interface ISMSNSURLSessionStreamHandler()
@property (nonnull, strong) NSURLSession *session;
@property (nullable, strong) NSURLSessionDataTask *dataTask;
@property (nullable, strong) NSURLRequest *request;
@end

@implementation ISMSNSURLSessionStreamHandler

- (instancetype)init {
    if (self = [super init]) {
        _session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:self delegateQueue:nil];
    }
    return self;
}

// Create the request and start the connection
- (void)start:(BOOL)resume {
    if (!resume) {
        // Clear temp cache if this is a temp file
        if (self.isTempCache) {
            [cacheS clearTempCache];
        }
    }
    
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler start:%@ for: %@", NSStringFromBOOL(resume), self.mySong.title);
    
    self.totalBytesTransferred = 0;
    self.bytesTransferred = 0;
    self.byteOffset = 0;
    
    // Create the file handle
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    
    if (self.fileHandle) {
        if (resume) {
            // File exists so seek to end
            self.totalBytesTransferred = [self.fileHandle seekToEndOfFile];
            self.byteOffset += self.totalBytesTransferred;
        } else {
            // File exists so remove it
            [self.fileHandle closeFile];
            self.fileHandle = nil;
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
        }
    }
    
    if (!resume) {
        // Create the file
        self.totalBytesTransferred = 0;
        [[NSFileManager defaultManager] createFileAtPath:self.filePath contents:[NSData data] attributes:nil];
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    }
    
    NSMutableDictionary *parameters = [@{@"id": n2N(self.mySong.songId), @"estimateContentLength": @"true"} mutableCopy];
    if (self.maxBitrateSetting == NSIntegerMax) {
        self.maxBitrateSetting = settingsS.currentMaxBitrate;
    }
    if (self.maxBitrateSetting != 0) {
        NSString *maxBitRate = [[NSString alloc] initWithFormat:@"%ld", (long)self.maxBitrateSetting];
        [parameters setObject:n2N(maxBitRate) forKey:@"maxBitRate"];
    }
    self.request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:(NSUInteger)self.byteOffset];
    if (!self.request) {
        DDLogVerbose(@"[ISMSURLConnectionStreamHandler] start connection failed");
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
        if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)])
            [self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
        return;
    }
    
    self.bitrate = self.mySong.estimatedBitrate;
    if ([self.mySong isEqualToSong:playlistS.currentSong]) {
        self.isCurrentSong = YES;
    }
    
    [self startConnection];
}

- (void)connectionTimedOut {
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler connectionTimedOut for %@", self.mySong);
    
    [self cancel];
    [self didFailInternal:nil];
}

- (void)startConnection {
    NSAssert(NSThread.isMainThread, @"startConnection must be called from the main thread");
    
    // TODO: Need to check if this is null?
    self.dataTask = [self.session dataTaskWithRequest:self.request];
    if (self.dataTask) {
        [self.dataTask resume];
        self.isDownloading = YES;
        DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler startConnectionInternalSuccess for %@", self.mySong);

        if (!self.isTempCache) {
            self.mySong.isPartiallyCached = YES;
        }
        
        [EX2NetworkIndicator usingNetwork];
        
        if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStarted:)]) {
            [self.delegate ISMSStreamHandlerStarted:self];
        }
        
        [self startTimeOutTimer];
    } else {
        DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] start connection failed");
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
        if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)]) {
            [self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
        }
    }
}

// Cancel the download
- (void)cancel {
    [self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
    
    if (self.isDownloading) {
        [EX2NetworkIndicator doneUsingNetwork];
    }
    
    self.isDownloading = NO;
    self.isCanceled = YES;
    
    // Pop out of infinite loop if partially pre-cached
    self.partialPrecacheSleep = NO;
    
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler request canceled for %@", self.mySong);
    [self.dataTask cancel];
    self.dataTask = nil;
    
    // Close the file handle
    [self.fileHandle closeFile];
    self.fileHandle = nil;
}

#pragma mark NSURLSession Delegate

// Allow self-signed SSL certificates
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler didReceiveResponse for %@", self.mySong);

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        //DLog(@"allHeaderFields: %@", [httpResponse allHeaderFields]);
        //DLog(@"statusCode: %i - %@", [httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
        
        if ([httpResponse statusCode] >= 500) {
            // This is a failure, cancel the connection and call the didFail delegate method
            [self.dataTask cancel];
//            [self connection:self.connection didFailWithError:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer]];
        } else if (self.contentLength == ULLONG_MAX) {
            // Set the content length if it isn't set already, only set the first connection, not on retries
            NSString *contentLengthString = [[httpResponse allHeaderFields] objectForKey:@"Content-Length"];
            if (contentLengthString) {
                self.contentLength = [contentLengthString longLongValue];
            }
        }
    }
    
    self.bytesTransferred = 0;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData size %lu totalBytesTransferred: %llu  bytesTransferred: %llu  thread: %@", data.length, self.totalBytesTransferred, self.bytesTransferred, NSThread.currentThread);
    [self performSelectorOnMainThread:@selector(stopTimeOutTimer) withObject:nil waitUntilDone:NO];
        
    if (self.isCanceled) {
        return;
    }
    
    if (isSpeedLoggingEnabled) {
        if (!self.speedLoggingDate) {
            self.speedLoggingDate = [NSDate date];
            self.speedLoggingLastSize = self.totalBytesTransferred;
        }
    }
    
    NSMutableDictionary *threadDict = [NSThread.currentThread threadDictionary];
    NSDate *throttlingDate = [threadDict objectForKey:@"throttlingDate"];
    NSUInteger dataLength = [data length];
    
    self.totalBytesTransferred += dataLength;
    self.bytesTransferred += dataLength;
    
    if (self.fileHandle) {
        // Save the data to the file
        @try {
            [self.fileHandle writeData:data];
        } @catch (NSException *exception) {
            //DLog(@"Failed to write to file %@, %@ - %@", self.mySong, exception.name, exception.description);
            [EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self cancel]; }];
        }
        
        // Notify delegate if enough bytes received to start playback
        if (!self.isDelegateNotifiedToStartPlayback && self.totalBytesTransferred >= ISMSMinBytesToStartPlayback(self.bitrate)) {
            //DLog(@"telling player to start, min bytes: %u, total bytes: %llu, bitrate: %u", ISMSMinBytesToStartPlayback(self.bitrate), self.totalBytesTransferred, self.bitrate);
            self.isDelegateNotifiedToStartPlayback = YES;
            //DLog(@"player told to start playback");
            [EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{ [self startPlaybackInternal]; }];
        }
        
        // Log progress
        if (isProgressLoggingEnabled) {
            DDLogInfo(@"[ISMSNSURLSessionStreamHandler] downloadedLengthA:  %llu   bytesRead: %lu", self.totalBytesTransferred, (unsigned long)dataLength);
        }
        
        // If near beginning of file, don't throttle
        if (self.totalBytesTransferred < ISMSMinBytesToStartLimiting(self.bitrate)) {
            [threadDict setObject:[NSDate date] forKey:@"throttlingDate"];
            self.bytesTransferred = 0;
        }
        
        if (self.isEnableRateLimiting) {
            // Check if we should throttle
            NSDate *now = [[NSDate alloc] init];
            NSTimeInterval intervalSinceLastThrottle = [now timeIntervalSinceDate:throttlingDate];
            if (intervalSinceLastThrottle > ISMSThrottleTimeInterval && self.totalBytesTransferred > ISMSMinBytesToStartLimiting(self.bitrate)) {
                NSTimeInterval delay = 0.0;
                
                double maxBytesPerInterval = [self.class maxBytesPerIntervalForBitrate:(double)self.bitrate is3G:![LibSub isWifi]];
                double numberOfIntervals = intervalSinceLastThrottle / ISMSThrottleTimeInterval;
                double maxBytesPerTotalInterval = maxBytesPerInterval * numberOfIntervals;
                
                if (self.bytesTransferred > maxBytesPerTotalInterval) {
                    double speedDifferenceFactor = (double)self.bytesTransferred / maxBytesPerTotalInterval;
                    delay = (speedDifferenceFactor * intervalSinceLastThrottle) - intervalSinceLastThrottle;
                    
                    if (isThrottleLoggingEnabled) {
                        DDLogInfo(@"[ISMSNSURLSessionStreamHandler] Pausing for %f  interval: %f  bytesTransferred: %llu maxBytes: %f", delay, intervalSinceLastThrottle, self.bytesTransferred, maxBytesPerTotalInterval);
                    }
                    
                    self.bytesTransferred = 0;
                }
                
                [NSThread sleepForTimeInterval:delay];
                
                if (self.isCanceled) {
                    return;
                }
                
                [threadDict setObject:[NSDate date] forKey:@"throttlingDate"];
            }
        }
        
        // Handle partial pre-cache next song
        if (!self.isCurrentSong && !self.isTempCache && settingsS.isPartialCacheNextSong && self.partialPrecacheSleep) {
            NSUInteger partialPrecacheSize = ISMSNumBytesToPartialPreCache(self.mySong.estimatedBitrate);
            if (self.totalBytesTransferred >= partialPrecacheSize) {
                [self performSelectorOnMainThread:@selector(partialPrecachePausedInternal) withObject:nil waitUntilDone:NO];
                while (self.partialPrecacheSleep && !self.tempBreakPartialPrecache) {
                    [NSThread sleepForTimeInterval:0.1];
                }
                self.tempBreakPartialPrecache = NO;
                [self performSelectorOnMainThread:@selector(partialPrecacheUnpausedInternal) withObject:nil waitUntilDone:NO];
            }
        }
    } else {
        DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler did receive data but encryptor was nil for %@", self.mySong);

        if (!self.isCanceled) {
            // There is no file handle for some reason, cancel the connection
            [self.dataTask cancel];
            [self performSelectorOnMainThread:@selector(didFailInternal:) withObject:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer] waitUntilDone:NO];
        }
    }
    
#if isSpeedLoggingEnabled
    if (isSpeedLoggingEnabled) {
        NSTimeInterval speedInteval = [[NSDate date] timeIntervalSinceDate:self.speedLoggingDate];
        
        // Check every 10 seconds
        if (speedInteval >= 10.0) {
            unsigned long long transferredSinceLastCheck = self.totalBytesTransferred - self.speedLoggingLastSize;
            
            double speedInBytes = (double)transferredSinceLastCheck / speedInteval;
            double speedInKbytes = speedInBytes / 1024.;
            DDLogInfo(@"[ISMSNSURLSessionStreamHandler] rate: %f  speedInterval: %f  transferredSinceLastCheck: %llu", speedInKbytes, speedInteval, transferredSinceLastCheck);
            
            self.speedLoggingLastSize = self.totalBytesTransferred;
            self.speedLoggingDate = [NSDate date];
        }
    }
#endif
    
    [self performSelectorOnMainThread:@selector(startTimeOutTimer) withObject:nil waitUntilDone:NO];
}

// Main Thread
- (void)partialPrecachePausedInternal {
    NSAssert(NSThread.isMainThread, @"partialPrecachePausedInternal must be called from the main thread");
    
    self.isPartialPrecacheSleeping = YES;

    if (!self.isCanceled) {
        [EX2NetworkIndicator doneUsingNetwork];
    }
    
    if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecachePaused:)]) {
        [self.delegate ISMSStreamHandlerPartialPrecachePaused:self];
    }
}

// Main Thread
- (void)partialPrecacheUnpausedInternal {
    NSAssert(NSThread.isMainThread, @"partialPrecacheUnpausedInternal must be called from the main thread");
    
    self.isPartialPrecacheSleeping = NO;
    
    if (!self.isCanceled) {
        [EX2NetworkIndicator usingNetwork];
    }
    
    if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerPartialPrecacheUnpaused:)]) {
        [self.delegate ISMSStreamHandlerPartialPrecacheUnpaused:self];
    }
}

// Main Thread
- (void)startPlaybackInternal {
    NSAssert(NSThread.isMainThread, @"startPlaybackInternal must be called from the main thread");
    
    if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerStartPlayback:)]) {
        [self.delegate ISMSStreamHandlerStartPlayback:self];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self performSelectorOnMainThread:@selector(didFailInternal:) withObject:error waitUntilDone:NO];
    } else {
        [self performSelectorOnMainThread:@selector(didFinishLoadingInternal) withObject:nil waitUntilDone:NO];
    }
}

// Main Thread
- (void)didFailInternal:(NSError *)error {
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler didFailInternal for %@", self.mySong);
    NSAssert(NSThread.isMainThread, @"didFailInternal must be called from the main thread");
    [self stopTimeOutTimer];
    
    DDLogError(@"[ISMSNSURLSessionStreamHandler] Connection Failed for %@", self.mySong.title);
    DDLogError(@"[ISMSNSURLSessionStreamHandler] error domain: %@  code: %ld description: %@", error.domain, (long)error.code, error.description);
    
    self.isDownloading = NO;
    self.dataTask = nil;
    
    // Close the file handle
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    
    [EX2NetworkIndicator doneUsingNetwork];
    
    if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFailed:withError:)]) {
        [self.delegate ISMSStreamHandlerConnectionFailed:self withError:error];
    }
}

// Main Thread
- (void)didFinishLoadingInternal {
    DDLogVerbose(@"[ISMSNSURLSessionStreamHandler] Stream handler didFinishLoadingInternal for %@", self.mySong);
    NSAssert(NSThread.isMainThread, @"didFinishLoadingInternal must be called from the main thread");
    [self stopTimeOutTimer];
    
    //DLog(@"localSize: %llu   contentLength: %llu", mySong.localFileSize, self.contentLength);
        
    // Check to see if we're at the contentLength (to allow some leeway for contentLength estimation of transcoded songs
    if (self.contentLength != ULLONG_MAX && self.mySong.localFileSize < self.contentLength && self.numberOfContentLengthFailures < ISMSMaxContentLengthFailures) {
        self.numberOfContentLengthFailures++;
        // This is a failed connection that didn't call didFailInternal for some reason, so call didFailWithError
        [self didFailInternal:[NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer]];
    } else {
        // Make sure the player is told to start
        if (!self.isDelegateNotifiedToStartPlayback) {
            self.isDelegateNotifiedToStartPlayback = YES;
            [self startPlaybackInternal];
        }
    }
 
    [self stopTimeOutTimer];
    
    self.isDownloading = NO;
    self.dataTask = nil;
    
    // Close the file handle
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    
    [EX2NetworkIndicator doneUsingNetwork];
    
    if ([self.delegate respondsToSelector:@selector(ISMSStreamHandlerConnectionFinished:)]) {
        [self.delegate ISMSStreamHandlerConnectionFinished:self];
    }
}

@end
