//
//  EX2Dispatch.m
//  EX2Kit
//
//  Created by Ben Baron on 4/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2Dispatch.h"
#import "NSArray+Additions.h"

@implementation EX2Dispatch

#pragma mark - Blocks after delay

+ (void)runInQueue:(dispatch_queue_t)queue delay:(NSTimeInterval)delay block:(void (^)(void))block {
	block = [block copy];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), queue, block);
}

+ (void)runInMainThreadAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block {
	[self runInQueue:dispatch_get_main_queue() delay:delay block:block];
}

+ (void)runInBackgroundAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block {
	[self runInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) delay:delay block:block];
}

#pragma mark - Blocks asynchronously

+ (void)runAsync:(dispatch_queue_t)queue block:(void (^)(void))block {
	block = [block copy];
	dispatch_async(queue, block);
}

+ (void)runInBackgroundAsync:(void (^)(void))block {
	[self runAsync:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) block:block];
}

+ (void)runInMainThreadAsync:(void (^)(void))block {
	[self runAsync:dispatch_get_main_queue() block:block];
}

#pragma mark - Blocks now

+ (void)runInQueue:(dispatch_queue_t)queue waitUntilDone:(BOOL)shouldWait block:(void (^)(void))block {
	block = [block copy];
    if (shouldWait) {
		dispatch_sync(queue, block);
    } else {
		dispatch_async(queue, block);
    }
}

+ (void)runInMainThreadAndWaitUntilDone:(BOOL)shouldWait block:(void (^)(void))block {
	// Calling dispatch_sync to the main queue from the main thread can cause a deadlock,
	// so just run the block
	if ([NSThread isMainThread] && shouldWait) {
        block();
        return;
	}
	
	[self runInQueue:dispatch_get_main_queue() waitUntilDone:shouldWait block:block];
}

@end
