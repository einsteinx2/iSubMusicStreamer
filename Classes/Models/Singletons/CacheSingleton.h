//
//  CacheSingleton.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_CacheSingleton_h
#define iSub_CacheSingleton_h

#import <Foundation/Foundation.h>

#define cacheS ((CacheSingleton *)[CacheSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Cache)
@interface CacheSingleton : NSObject

@property NSTimeInterval cacheCheckInterval;
@property (readonly) unsigned long long totalSpace;
@property (readonly) unsigned long long cacheSize;
@property (readonly) unsigned long long freeSpace;
@property (readonly) NSUInteger numberOfCachedSongs;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());
+ (void)setAllCachedSongsToBackup;
+ (void)setAllCachedSongsToNotBackup;

//- (void)startCacheCheckTimer;
- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval;
- (void)stopCacheCheckTimer;
- (void)clearTempCache;
- (void)findCacheSize;

+ (void)setAllSongsToBackup;
+ (void)setAllSongsToNotBackup;

@end

NS_ASSUME_NONNULL_END

#endif
