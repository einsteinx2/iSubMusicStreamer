//
//  NSNotificationCenter+MainThread.h
//  EX2Kit
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@interface NSNotificationCenter (MainThread)

+ (void)postNotificationToMainThreadWithName:(NSString *)name;
+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object;
+ (void)postNotificationToMainThreadWithName:(NSString *)name userInfo:(NSDictionary *)userInfo;
+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo;

+ (void)addObserverOnMainThread:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(id)notificationSender;
+ (void)addObserverOnMainThreadAsync:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(id)notificationSender;

+ (void)removeObserverOnMainThread:(id)notificationObserver;
+ (void)removeObserverOnMainThread:(id)notificationObserver name:(NSString *)notificationName object:(id)notificationSender;

@end