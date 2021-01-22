//
//  ISMSCacheQueueManager.h
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"

#define cacheQueueManagerS ((ISMSCacheQueueManager *)[ISMSCacheQueueManager sharedInstance])

@class ISMSSong, ISMSAbstractStreamHandler;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(CacheQueue)
@interface ISMSCacheQueueManager : NSObject <ISMSStreamHandlerDelegate>

@property BOOL isQueueDownloading;
@property (nullable, copy) ISMSSong *currentQueuedSong;
@property (nullable, strong) ISMSAbstractStreamHandler *currentStreamHandler;
@property (nullable, weak, readonly) ISMSSong *currentQueuedSongInDb;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(NSNumber *)byteOffset;

- (void)removeCurrentSong;

- (BOOL)isSongInQueue:(ISMSSong *)aSong;

@end

NS_ASSUME_NONNULL_END
