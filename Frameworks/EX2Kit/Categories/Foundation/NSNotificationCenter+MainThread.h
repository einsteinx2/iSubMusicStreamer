//
//  NSNotificationCenter+MainThread.h
//  EX2Kit
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNotificationCenter (MainThread)

+ (void)postNotificationToMainThreadWithName:(NSString *)name NS_SWIFT_NAME(postNotificationToMainThread(name:));
+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(nullable id)object NS_SWIFT_NAME(postNotificationToMainThread(name:object:));
+ (void)postNotificationToMainThreadWithName:(NSString *)name userInfo:(nullable NSDictionary *)userInfo NS_SWIFT_NAME(postNotificationToMainThread(name:userInfo:));
+ (void)postNotificationToMainThreadWithName:(NSString *)name object:(nullable id)object userInfo:(nullable NSDictionary *)userInfo NS_SWIFT_NAME(postNotificationToMainThread(name:object:userInfo:));

+ (void)addObserverOnMainThread:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(nullable id)notificationSender NS_SWIFT_NAME(addObserverOnMainThread(_:selector:name:object:));
+ (void)addObserverOnMainThreadAsync:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(nullable id)notificationSender NS_SWIFT_NAME(addObserverOnMainThreadAsync(_:selector:name:object:));

+ (void)removeObserverOnMainThread:(id)notificationObserver NS_SWIFT_NAME(removeObserverOnMainThread(_:));
+ (void)removeObserverOnMainThread:(id)notificationObserver name:(NSString *)notificationName object:(nullable id)notificationSender NS_SWIFT_NAME(removeObserverOnMainThread(_:name:object:));

@end

NS_ASSUME_NONNULL_END
