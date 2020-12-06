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

+ (void)addObserverOnMainThread:(id)observer selector:(SEL)selector name:(NSString *)name object:(nullable id)notificationSender NS_SWIFT_NAME(addObserverOnMainThread(_:selector:name:object:));
+ (void)addObserverOnMainThread:(id)observer selector:(SEL)selector name:(NSString *)name NS_SWIFT_NAME(addObserverOnMainThread(_:selector:name:));
+ (void)addObserverOnMainThreadAsync:(id)observer selector:(SEL)selector name:(NSString *)name object:(nullable id)notificationSender NS_SWIFT_NAME(addObserverOnMainThreadAsync(_:selector:name:object:));
+ (void)addObserverOnMainThreadAsync:(id)observer selector:(SEL)selector name:(NSString *)name NS_SWIFT_NAME(addObserverOnMainThreadAsync(_:selector:name:));
+ (id <NSObject>)addObserverOnMainThreadForName:(NSString *)name object:(nullable id)object usingBlock:(void (^)(NSNotification *note))block NS_SWIFT_NAME(addObserverOnMainThreadForName(_:object:handler:));
+ (id <NSObject>)addObserverOnMainThreadForName:(NSString *)name usingBlock:(void (^)(NSNotification *note))block NS_SWIFT_NAME(addObserverOnMainThreadForName(_:handler:));

+ (void)removeObserverOnMainThread:(id)observer NS_SWIFT_NAME(removeObserverOnMainThread(_:));
+ (void)removeObserverOnMainThread:(id)observer name:(NSString *)name object:(nullable id)objct NS_SWIFT_NAME(removeObserverOnMainThread(_:name:object:));
+ (void)removeObserverOnMainThread:(id)observer name:(NSString *)name NS_SWIFT_NAME(removeObserverOnMainThread(_:name:));

@end

NS_ASSUME_NONNULL_END
