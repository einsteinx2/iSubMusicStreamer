//
//  HLSProxyResponse.m
//  libSub
//
//  Created by Benjamin Baron on 1/5/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "HLSProxyResponse.h"
#import "HTTPConnection.h"
#import "EX2Kit.h"
#import "EX2RingBuffer.h"

static const int ddLogLevel = LOG_LEVEL_ERROR;

@interface HLSProxyResponse ()
{
    UInt8		_buffer[16 * 1024];				//	Create a 16K buffer
	CFIndex		_bytesRead;
    CFReadStreamRef _readStreamRef;
}
@property (strong) EX2RingBuffer *proxyBuffer;
@property (strong) NSURLRequest *proxyRequest;
@property SInt64 proxyContentLength;
@property SInt64 proxyStatusCode;
@property BOOL isDownloadStarted;
@property BOOL isDownloadFinished;
@property NSThread *downloadThread;
- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type;
@end

@implementation HLSProxyResponse

#pragma mark - Lifecycle

- (instancetype)initWithConnection:(HTTPConnection *)serverConnection
{
    if ((self = [super init]))
    {
        _serverConnection = serverConnection;
    }
    return self;
}

- (void)dealloc
{
    [self performSelector:@selector(terminateDownload) onThread:self.downloadThread withObject:nil waitUntilDone:YES];
}

#pragma mark - HTTPResponse Protocol Methods

// Don't support range requests
- (UInt64)offset { return 0; }
- (void)setOffset:(UInt64)offset { }

// Return the content length we got from the proxy connection
- (UInt64)contentLength
{
    UInt64 contentLength = self.proxyContentLength < 0 ? 0 : self.proxyContentLength;
    
    DDLogVerbose(@"HLSProxyResponse asking contentLength, replying with %llu", contentLength);
    return contentLength;
}

// Only reply with done with the connection has finished plus the buffer is empty
- (BOOL)isDone
{
    // Make sure there are bytes if the request and the proxy connection are not in sync, otherwise it hangs for some reason
    while (self.proxyBuffer.filledSpaceLength == 0 && !self.isDownloadFinished)
    {
        // Wait for bytes
        DDLogVerbose(@"HLSProxyResponse (%@) Waiting for bytes", self);
        [NSThread sleepForTimeInterval:.01];
    }
    
    BOOL isDone = self.isDownloadFinished && self.proxyBuffer.filledSpaceLength == 0;
    DDLogVerbose(@"HLSProxyResponse (%@) asking if done, replying %@   isDownloadFinished %@   filledSpaceLength %lu", self, NSStringFromBOOL(isDone), NSStringFromBOOL(self.isDownloadFinished), (unsigned long)self.proxyBuffer.filledSpaceLength);
    return isDone;
}

// Read data from the download buffer
- (NSData *)readDataOfLength:(NSUInteger)length
{
    DDLogVerbose(@"HLSProxyResponse (%@) asking for bytes, available in buffer: %lu", self, (unsigned long)self.proxyBuffer.filledSpaceLength);
    NSData *data = [self.proxyBuffer drainData:length];
    DDLogVerbose(@"HLSProxyResponse (%@) read data of length: %lu actual length: %lu", self, (unsigned long)length, (unsigned long)data.length);
    return data;
}

// Delay the response headers so that we can return the correct status code in case we get a 404 or something
- (BOOL)delayResponseHeaders
{
    BOOL delayResponseHeaders = !self.isDownloadStarted;
    DDLogVerbose(@"HLSProxyResponse asking if delayResponseHeaders, replying with %@", NSStringFromBOOL(delayResponseHeaders));
    return delayResponseHeaders;
}

// Return the status code we got from the server
- (NSInteger)status
{
    NSInteger status;
    
    // If we had a redirect and somehow the final connection didn't update the status code, we return 200 so
    // we don't confuse the client
    if (self.proxyStatusCode >= 300 && self.proxyStatusCode < 400)
    {
        status = 200;
    }
    else
    {
        status =  (NSUInteger)self.proxyStatusCode;
    }
    DDLogVerbose(@"HLSProxyResponse asking status, replying with %li", (long)status);
    return status;
}

- (BOOL)isChunked
{
    // Only chunked when we don't know the content length, otherwise pass along the content length from the server
    BOOL isChunked = self.contentLength == 0;
    
    DDLogVerbose(@"HLSProxyResponse asking isChunked, replying with %@", NSStringFromBOOL(isChunked));
    return isChunked;
}

- (void)connectionDidClose
{
    DDLogVerbose(@"HLSProxyResponse connectionDidClose");
    
    [self performSelector:@selector(terminateDownload) onThread:self.downloadThread withObject:nil waitUntilDone:NO];
}

#pragma mark - Proxy Downloading Methods

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

- (void)startProxyDownload:(NSURL *)url
{
    self.downloadThread = [[NSThread alloc] initWithTarget:self selector:@selector(startProxyDownloadInternal:) object:url];
    [self.downloadThread start];
}

- (void)startProxyDownloadInternal:(NSURL *)url
{
    self.proxyRequest = [[NSURLRequest alloc] initWithURL:url];
    
    CFStreamClientContext ctxt = {0, (__bridge void*)self, NULL, NULL, NULL};
        
    // Make sure the request URL is not nil, or we will have a strange looking SIGTRAP crash with a misleading stack trace
    if (!self.proxyRequest.URL)
        [self bail: NULL];
	
	// Create the request
	CFHTTPMessageRef messageRef = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (__bridge CFStringRef)self.proxyRequest.HTTPMethod, (__bridge CFURLRef)self.proxyRequest.URL, kCFHTTPVersion1_1);
	if (messageRef == NULL) 
        [self bail: NULL];
    
    // Set the URL
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("HOST"), (__bridge CFStringRef)[self.proxyRequest.URL host]);
	
    // Set the request type
    if ([self.proxyRequest.HTTPMethod isEqualToString:@"POST"])
    {
        CFHTTPMessageSetBody(messageRef, (__bridge CFDataRef)self.proxyRequest.HTTPBody);
    }
    
    // Set all the headers
    if (self.proxyRequest.allHTTPHeaderFields.count > 0)
    {
        for (NSString *key in self.proxyRequest.allHTTPHeaderFields.allKeys)
        {
            NSString *value = [self.proxyRequest.allHTTPHeaderFields objectForKey:key];
            if (value)
                CFHTTPMessageSetHeaderFieldValue(messageRef, (__bridge CFStringRef)key, (__bridge CFStringRef)value);
        }
    }
		
	// Create the stream for the request.
	_readStreamRef = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, messageRef);
	if (_readStreamRef == NULL) [self bail: messageRef];
	
	//	There are times when a server checks the User-Agent to match a well known browser.  This is what Safari used at the time the sample was written
	//CFHTTPMessageSetHeaderFieldValue( messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125"));
	
	// Enable stream redirection
	if (CFReadStreamSetProperty(_readStreamRef, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue) == false)
		[self bail: messageRef];
	
	// Handle SSL connections
	if([[self.proxyRequest.URL absoluteString] rangeOfString:@"https"].location != NSNotFound)
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
		[self bail: messageRef];
	
	// Schedule the stream
	CFReadStreamScheduleWithRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
	// Start the HTTP connection
	if (CFReadStreamOpen(_readStreamRef) == false)
		[self bail: messageRef];
    
    // Initialize the ring buffer. Choosing a small starting value as it is getting read from about as fast as it's being written to
    // but just in case we'll use a large enough maximum length to hold a whole segment of the largest bitrate we support
    self.proxyBuffer = [[EX2RingBuffer alloc] initWithBufferLength:BytesFromKiB(100)];
    self.proxyBuffer.maximumLength = BytesFromMiB(3.5);
		
	if (messageRef != NULL) CFRelease(messageRef);
	return;
}

-(void)bail:(CFHTTPMessageRef)messageRef
{
    if (messageRef != NULL) 
        CFRelease(messageRef);
	[self terminateDownload];
}

- (void)retreiveHeaderValues
{
    if (_readStreamRef == NULL)
        return;
    
    self.proxyStatusCode = 0;
    self.proxyContentLength = 0;
    CFHTTPMessageRef myResponse = (CFHTTPMessageRef)CFReadStreamCopyProperty(_readStreamRef, kCFStreamPropertyHTTPResponseHeader);
    if (myResponse != NULL)
    {
        // Get the HTTP status code
        self.proxyStatusCode = CFHTTPMessageGetResponseStatusCode(myResponse);
        
        // Get the content length (must grab the dict because using CFHTTPMessageCopyHeaderFieldValue if the value doesn't exist will cause an EXC_BAD_ACCESS
        CFDictionaryRef headerDict = CFHTTPMessageCopyAllHeaderFields(myResponse);
        if (headerDict != NULL)
        {
            if (CFDictionaryContainsKey(headerDict, CFSTR("Content-Length")))
            {
                CFStringRef length = CFHTTPMessageCopyHeaderFieldValue(myResponse, CFSTR("Content-Length"));
                if (length != NULL)
                {
                    self.proxyContentLength = [(__bridge NSString *)length longLongValue];
                    CFRelease(length);
                }
            }
            CFRelease(headerDict);
        }
        CFRelease(myResponse);
    }
    
    DDLogVerbose(@"HLSProxyResponse got headers, status code: %lli  content length: %lli", self.proxyStatusCode, self.proxyContentLength);
}

static void ReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
	@autoreleasepool
	{
		[(__bridge HLSProxyResponse *)clientCallBackInfo readStreamClientCallBack:stream type:type];
	}
}

- (void)readStreamClientCallBack:(CFReadStreamRef)stream type:(CFStreamEventType)type
{
	if (type == kCFStreamEventOpenCompleted)
	{
        [self.proxyBuffer reset];
	}
	else if (type == kCFStreamEventHasBytesAvailable)
	{
		_bytesRead = CFReadStreamRead(stream, _buffer, sizeof(_buffer));
        
		if (_bytesRead > 0)	// If zero bytes were read, wait for the EOF to come.
		{
            // We do this here because if kCFStreamEventOpenCompleted is like NSURLConnection's didReceiveResponse, it may be called more than once
            if (!self.isDownloadStarted)
            {
                [self retreiveHeaderValues];
                                
                self.isDownloadStarted = YES;
                [self.serverConnection responseHasAvailableData:self];
            }
            
            [self.proxyBuffer fillWithBytes:_buffer length:_bytesRead];
            DDLogCVerbose(@"HLSProxyResponse (%@) filling buffer with data of length %lu", self, _bytesRead);
		}
		else if (_bytesRead < 0)		// Less than zero is an error
		{
			DDLogCError(@"[HLSProxyResponse] Stream handler: An occured in the download bytesRead < 0");
			[self downloadFailed];
		}
		else	//	0 assume we are done with the stream
		{
			DDLogCVerbose(@"[HLSProxyResponse] Stream handler: bytesRead == 0 occured in the download, so we're assuming we're finished");
			[self downloadDone];
		}
	}
	else if (type == kCFStreamEventEndEncountered)
	{
		DDLogCVerbose(@"[HLSProxyResponse] Stream handler: An kCFStreamEventEndEncountered occured in the download, download is done");
		[self downloadDone];
	}
	else if (type == kCFStreamEventErrorOccurred)
	{
		DDLogCError(@"[HLSProxyResponse] Stream handler: An kCFStreamEventErrorOccurred occured in the download");
		[self downloadFailed];
	}
}

- (void)downloadFailed
{
	DDLogError(@"HLSProxyResponse failed to download: %@", self.proxyRequest.URL.absoluteString);
    self.isDownloadFinished = YES;
    
    [self terminateDownload];
}

- (void)downloadDone
{
	DDLogVerbose(@"HLSProxyResponse finished download: %@", self.proxyRequest.URL.absoluteString);
    self.isDownloadFinished = YES;
    
    [self terminateDownload];
}

- (void)terminateDownload
{	
    if (_readStreamRef == NULL)
    {
        return;
    }
    
    //***	ALWAYS set the stream client (notifier) to NULL if you are releasing it
    //	otherwise your notifier may be called after you released the stream leaving you with a
    //	bogus stream within your notifier.
    //DLog(@"canceling stream: %@", readStreamRef);
    CFReadStreamSetClient(_readStreamRef, kCFStreamEventNone, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(_readStreamRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    CFReadStreamClose(_readStreamRef);
    CFRelease(_readStreamRef);
    
    _readStreamRef = NULL;
    
    // Stop run loop
    CFRunLoopStop(CFRunLoopGetCurrent());
}

@end
