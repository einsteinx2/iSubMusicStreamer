//
//  ISMSCacheQueueManager.h
//  iSub
//
//  Created by Ben Baron on 2/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"

#define cacheQueueManagerS ((ISMSCacheQueueManager *)[ISMSCacheQueueManager sharedInstance])

@class ISMSSong, ISMSStreamHandler;
@interface ISMSCacheQueueManager : NSObject <ISMSStreamHandlerDelegate>

@property BOOL isQueueDownloading;
@property (copy) ISMSSong *currentQueuedSong;
@property (strong) ISMSStreamHandler *currentStreamHandler;
@property (weak, readonly) ISMSSong *currentQueuedSongInDb;

+ (instancetype)sharedInstance;

- (void)startDownloadQueue;
- (void)stopDownloadQueue;
- (void)resumeDownloadQueue:(NSNumber *)byteOffset;

- (void)removeCurrentSong;

- (BOOL)isSongInQueue:(ISMSSong *)aSong;

@end
