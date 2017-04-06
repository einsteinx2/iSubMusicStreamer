//
//  EX2SimpleConnectionQueue.h
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

#import <Foundation/Foundation.h>

// Notifications
#define EX2SimpleConnectionQueueDidStart @"EX2SimpleConnectionQueueDidStart"
#define EX2SimpleConnectionQueueDidStop @"EX2SimpleConnectionQueueDidStop"
#define EX2SimpleConnectionQueueDidClear @"EX2SimpleConnectionQueueDidClear"
#define EX2SimpleConnectionQueueConnectionDidFinish @"EX2SimpleConnectionQueueConnectionDidFinish"

@protocol EX2SimpleConnectionQueueDelegate;

// Class
@interface EX2SimpleConnectionQueue : NSObject

@property (weak) id <EX2SimpleConnectionQueueDelegate> delegate;

@property NSUInteger numberOfConcurrentConnections;
@property NSTimeInterval delayBetweenConnections;

@property BOOL isStartConnectionsAutomatically;

@property (readonly, strong) NSMutableArray *activeConnectionStack;
@property (readonly, strong) NSMutableArray *waitingConnectionStack;
@property (readonly) BOOL isRunning;

@property (readonly) float progress;

- (void)registerConnection:(NSURLConnection *)connection;
- (void)connectionFinished:(NSURLConnection *)connection;

- (void)startQueue;
- (void)stopQueue;
- (void)clearQueue;

@end

// Delegate Protocol
@protocol EX2SimpleConnectionQueueDelegate <NSObject>

@optional
- (void)connectionQueueDidFinish:(EX2SimpleConnectionQueue *)connectionQueue;

@end
