//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"
#import "ISMSLoaderDelegate.h"

#define streamManagerS ((ISMSStreamManager *)[ISMSStreamManager sharedInstance])

#define ISMSNumberOfStreamsToQueue 2

@class ISMSSong, ISMSStreamHandler, SUSLyricsDAO;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate, ISMSLoaderDelegate>

@property (strong) NSMutableArray *handlerStack;
@property (strong) SUSLyricsDAO *lyricsDAO;

@property (copy) ISMSSong *lastCachedSong;
@property (copy) ISMSSong *lastTempCachedSong;

@property (readonly) BOOL isQueueDownloading;

@property (readonly) ISMSSong *currentStreamingSong;

+ (id)sharedInstance;

- (void)delayedSetup;

- (ISMSStreamHandler *)handlerForSong:(ISMSSong *)aSong;
- (BOOL)isSongInQueue:(ISMSSong *)aSong;
- (BOOL)isSongFirstInQueue:(ISMSSong *)aSong;
- (BOOL)isSongDownloading:(ISMSSong *)aSong;

- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(ISMSSong *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(ISMSSong *)aSong;

- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(ISMSSong *)aSong;
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
