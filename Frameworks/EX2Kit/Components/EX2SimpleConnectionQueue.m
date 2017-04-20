//
//  EX2SimpleConnectionQueue.m
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// * Neither my name nor the names of my contributors may be used to endorse
// or promote products derived from this software without specific prior written
// permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
// SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
// DAMAGE.
//
// --------------------------------------------------
//
// Example usage:
// (Note the "startImmediately:NO" in the NSURLConnection)
//
//	EX2SimpleConnectionQueue *connectionQueue = [[EX2SimpleConnectionQueue alloc] init];
//
//	NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
//	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0];
//	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:connDelegate startImmediately:NO];
//	if (connection)
//	{
//		[connectionQueue registerConnection:connection];
//		[connectionQueue startQueue];
//	}
//	else
//	{
//		NSLog(@"Error creating connection");
//	}
//

#import "EX2SimpleConnectionQueue.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface EX2SimpleConnectionQueue ()
{
    NSUInteger _numberOfCompletedConnections;
}
@end

@implementation EX2SimpleConnectionQueue

- (id)init
{
	if (self = [super init])
	{
		_waitingConnectionStack = [[NSMutableArray alloc] init];
        _activeConnectionStack = [[NSMutableArray alloc] init];
		_isRunning = NO;
        _numberOfConcurrentConnections = 3;
        _isStartConnectionsAutomatically = YES;
	}
	
	return self;
}

- (void)registerConnection:(NSURLConnection *)connection
{
	[self.waitingConnectionStack addObject:connection];
    
    if (self.isStartConnectionsAutomatically)
        [self startQueue];
    
	DDLogVerbose(@"[EX2SimpleConnectionQueue] CONNECTION QUEUE REGISTER: %lu connections waiting, %lu active", (unsigned long)self.waitingConnectionStack.count, (unsigned long)self.activeConnectionStack.count);
}

- (void)startNextConnection
{
    // Make sure we always run in the same thread
    [EX2Dispatch runInMainThreadAfterDelay:self.delayBetweenConnections block:^
     {
         if (self.isRunning && self.waitingConnectionStack.count > 0 && self.activeConnectionStack.count < self.numberOfConcurrentConnections)
         {
             NSURLConnection *connection = [self.waitingConnectionStack objectAtIndex:0];
             [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
             [connection start];
             
             [self.activeConnectionStack addObject:connection];
             [self.waitingConnectionStack removeObjectAtIndex:0];
         }
     }];
}

- (void)connectionFinished:(NSURLConnection *)connection
{
    // Make sure this is always the main thread
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^
     {
         _numberOfCompletedConnections++;
         
         [self.activeConnectionStack removeObjectSafe:connection];
         
         DDLogVerbose(@"[EX2SimpleConnectionQueue] CONNECTION QUEUE FINISHED: %lu connections waiting, %lu active", (unsigned long)self.waitingConnectionStack.count, (unsigned long)self.activeConnectionStack.count);
         
         if (self.activeConnectionStack.count + self.waitingConnectionStack.count == 0)
         {
             _isRunning = NO;
             _numberOfCompletedConnections = 0;
             [self.delegate connectionQueueDidFinish:self];
             
             [NSNotificationCenter postNotificationToMainThreadWithName:EX2SimpleConnectionQueueDidStop object:self];
         }
         else
         {
             [self startNextConnection];
             [NSNotificationCenter postNotificationToMainThreadWithName:EX2SimpleConnectionQueueConnectionDidFinish object:self];
         }
     }];
}

- (void)startQueue
{
    if (self.waitingConnectionStack.count > 0 && self.activeConnectionStack.count < self.numberOfConcurrentConnections)
    {
        _isRunning = YES;
        
        [self startNextConnection];
        
        [NSNotificationCenter postNotificationToMainThreadWithName:EX2SimpleConnectionQueueDidStart object:self];
    }
}

- (void)stopQueue
{
	_isRunning = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:EX2SimpleConnectionQueueDidStop object:self];
}

- (void)clearQueue
{    
    _isRunning = NO;
    _numberOfCompletedConnections = 0;
	
	for (NSURLConnection *connection in self.activeConnectionStack)
	{
		[connection cancel];
	}
	
	[self.activeConnectionStack removeAllObjects];
    [self.waitingConnectionStack removeAllObjects];
    
    [NSNotificationCenter postNotificationToMainThreadWithName:EX2SimpleConnectionQueueDidClear object:self];
}

- (float)progress
{
    // Completed over all active, waiting, and finished connections, will always be a value between 0 and 1
    return (float)_numberOfCompletedConnections / (CGFloat)(self.activeConnectionStack.count + self.waitingConnectionStack.count + _numberOfCompletedConnections);
}

@end
