//
//  BassUserInfo.h
//  iSub
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "bass.h"

NS_ASSUME_NONNULL_BEGIN

@class ISMSSong, BassGaplessPlayer;
@interface BassStream : NSObject

@property (nullable, strong, nonatomic) BassGaplessPlayer *player;

@property (nonatomic) HSTREAM stream;
@property (nullable, nonatomic, copy) ISMSSong *song;

@property (nullable, strong, nonatomic) NSFileHandle *fileHandle;
@property BOOL shouldBreakWaitLoop;
@property BOOL shouldBreakWaitLoopForever;
@property unsigned long long neededSize;
@property BOOL isWaiting;
@property (nullable, nonatomic, copy) NSString *writePath;
@property (nonatomic, readonly) unsigned long long localFileSize;
@property (nonatomic) BOOL isTempCached;
@property BOOL isSongStarted;
@property BOOL isFileUnderrun;
@property BOOL wasFileJustUnderrun;
@property NSInteger channelCount;
@property NSInteger sampleRate;

@property BOOL isEnded;
@property BOOL isEndedCalled;
@property (nonatomic) NSInteger bufferSpaceTilSongEnd;

@property BOOL isNextSongStreamFailed;

@end

NS_ASSUME_NONNULL_END
