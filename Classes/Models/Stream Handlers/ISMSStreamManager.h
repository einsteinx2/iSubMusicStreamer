//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"

#define streamManagerS ((ISMSStreamManager *)[ISMSStreamManager sharedInstance])

#define ISMSNumberOfStreamsToQueue 2

NS_ASSUME_NONNULL_BEGIN

@class ISMSSong, ISMSStreamHandler;
NS_SWIFT_NAME(StreamManager)
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate>

@property (strong) NSMutableArray<ISMSStreamHandler*> *handlerStack;

@property (nullable, copy) ISMSSong *lastCachedSong;
@property (nullable, copy) ISMSSong *lastTempCachedSong;

@property (readonly) BOOL isQueueDownloading;

@property (readonly) ISMSSong *currentStreamingSong;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)delayedSetup;

- (nullable ISMSStreamHandler *)handlerForSong:(ISMSSong *)aSong;
- (BOOL)isSongInQueue:(ISMSSong *)aSong;
- (BOOL)isSongFirstInQueue:(ISMSSong *)aSong;
- (BOOL)isSongDownloading:(ISMSSong *)aSong;

- (void)cancelAllStreamsExcept:(nullable NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(nullable NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(nullable ISMSSong *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(ISMSSong *)aSong;

- (void)removeAllStreamsExcept:(nullable NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(nullable NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(nullable ISMSSong *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(ISMSStreamHandler *)handler;
- (void)removeStreamForSong:(ISMSSong *)aSong;

- (void)queueStreamForSong:(ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(ISMSSong *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(ISMSSong *)song isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;

- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)resumeHandler:(ISMSStreamHandler *)handler;
- (void)startHandler:(ISMSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(ISMSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

- (void)stealHandlerForCacheQueue:(ISMSStreamHandler *)handler;

@end

NS_ASSUME_NONNULL_END
