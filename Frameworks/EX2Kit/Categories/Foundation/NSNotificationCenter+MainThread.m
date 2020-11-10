//
//  NSNotificationCenter+MainThread.m
//  EX2Kit
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSNotificationCenter+MainThread.h"
#import "EX2Dispatch.h"

@implementation NSNotificationCenter (MainThread)

+ (void)postNotificationInternal:(NSDictionary *)info
{
    NSString *name = info[@"name"];
    id object = info[@"object"];
    NSDictionary *userInfo = info[@"userInfo"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo
{
	// Don't send a notification without a name
	if (name == nil)
		return;
	
	// If this is already the main thread, just call the method directly
	if ([NSThread isMainThread])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:name object:object userInfo:userInfo];
		return;
	}
	
	// This is a background thread so call it from the main thread
	@autoreleasepool 
	{
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:name forKey:@"name"];
		if (object)
            info[@"object"] = object;
		if (userInfo)
            info[@"userInfo"] = userInfo;
		
		[NSNotificationCenter performSelectorOnMainThread:@selector(postNotificationInternal:) 
											   withObject:info
											waitUntilDone:NO];
	}
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name userInfo:(NSDictionary *)userInfo
{
    [self postNotificationToMainThreadWithName:name object:nil userInfo:userInfo];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object
{
    [self postNotificationToMainThreadWithName:name object:object userInfo:nil];
}

+ (void)postNotificationToMainThreadWithName:(NSString *)name
{
    [self postNotificationToMainThreadWithName:name object:nil userInfo:nil];
}

/*
 *
 */

+ (void)addObserverOnMainThread:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(id)notificationSender
{
    // Ensure this runs in the main thread
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{
        [[NSNotificationCenter defaultCenter] addObserver:notificationObserver selector:notificationSelector name:notificationName object:notificationSender];
    }];
}

+ (void)addObserverOnMainThreadAsync:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(id)notificationSender
{
    // Ensure this runs in the main thread
    [EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^{
        [[NSNotificationCenter defaultCenter] addObserver:notificationObserver selector:notificationSelector name:notificationName object:notificationSender];
    }];
}

/*
*
*/

+ (void)removeObserverOnMainThread:(id)notificationObserver
{
    // Ensure this runs in the main thread
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    }];
}

+ (void)removeObserverOnMainThread:(id)notificationObserver name:(NSString *)notificationName object:(id)notificationSender
{
    // Ensure this runs in the main thread
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver name:notificationName object:notificationSender];
    }];
}

@end
