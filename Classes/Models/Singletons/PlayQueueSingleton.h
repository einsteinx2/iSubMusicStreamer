//
//  PlaylistSingleton.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_PlaylistSingleton_h
#define iSub_PlaylistSingleton_h

#import <Foundation/Foundation.h>

#define playlistS ((PlayQueueSingleton *)[PlayQueueSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

typedef enum {
	ISMSRepeatMode_Normal = 0,
	ISMSRepeatMode_RepeatOne = 1,
	ISMSRepeatMode_RepeatAll = 2
} ISMSRepeatMode;

@class ISMSSong, FMDatabase;
NS_SWIFT_NAME(PlayQueue)
@interface PlayQueueSingleton : NSObject {
	NSInteger shuffleIndex;
	NSInteger normalIndex;
	ISMSRepeatMode repeatMode;
}

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (nullable ISMSSong *)songForIndex:(NSUInteger)index;
- (NSInteger)decrementIndex;
- (NSInteger)incrementIndex;

- (NSUInteger)indexForOffset:(NSInteger)offset fromIndex:(NSInteger)index;
- (NSUInteger)indexForOffsetFromCurrentIndex:(NSInteger)offset;

// Convenience properties
- (nullable ISMSSong *)prevSong;
- (nullable ISMSSong *)currentDisplaySong;
- (nullable ISMSSong *)currentSong;
- (nullable ISMSSong *)nextSong;

@property NSInteger shuffleIndex;
@property NSInteger normalIndex;

@property NSInteger currentIndex;
@property (readonly) NSInteger prevIndex;
@property (readonly) NSInteger nextIndex;
@property (readonly) NSUInteger count;

@property ISMSRepeatMode repeatMode;

@property BOOL isShuffle;

- (void)deleteSongs:(NSArray *)indexes;
- (void)shuffleToggle;

@end

NS_ASSUME_NONNULL_END

#endif
