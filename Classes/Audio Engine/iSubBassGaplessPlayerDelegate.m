//
//  iSubBassGaplessPlayerDelegate.m
//  iSub
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "iSubBassGaplessPlayerDelegate.h"
#import "BassGaplessPlayer.h"
#import "Defines.h"
#import "EX2Dispatch.h"
#import "Swift.h"

@implementation iSubBassGaplessPlayerDelegate

- (instancetype)init {
    if (self = [super init]) {
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(grabCurrentPlaylistIndex:) name:Notifications.currentPlaylistOrderChanged object:nil];
        [NSNotificationCenter addObserverOnMainThread:self selector:@selector(grabCurrentPlaylistIndex:) name:Notifications.currentPlaylistShuffleToggled object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)grabCurrentPlaylistIndex:(NSNotification *)notification {
    
}

- (void)bassSeekToPositionStarted:(BassGaplessPlayer*)player {
    
}

- (void)bassSeekToPositionSuccess:(BassGaplessPlayer*)player {
    
}

- (void)bassStopped:(BassGaplessPlayer*)player {
    
}

- (void)bassFirstStreamStarted:(BassGaplessPlayer*)player {
    [Social.shared playerClearSocial];
}

- (void)bassSongEndedCalled:(BassGaplessPlayer*)player {
    // Increment current playlist index
    (void)[PlayQueue.shared incrementIndex];
    
    // Clear the social post status
    [Social.shared playerClearSocial];
}

- (void)bassFreed:(BassGaplessPlayer *)player {
    [Social.shared playerClearSocial];
}

- (NSInteger)bassIndexAtOffset:(NSInteger)offset fromIndex:(NSInteger)index player:(BassGaplessPlayer *)player {
    return [PlayQueue.shared indexWithOffset:offset fromIndex:index];
}

- (ISMSSong *)bassSongForIndex:(NSInteger)index player:(BassGaplessPlayer *)player {
    return [PlayQueue.shared songWithIndex:index];
}

- (NSInteger)bassCurrentPlaylistIndex:(BassGaplessPlayer *)player {
    return PlayQueue.shared.currentIndex;
}

- (void)bassRetrySongAtIndex:(NSInteger)index player:(BassGaplessPlayer*)player; {
    [EX2Dispatch runInMainThreadAsync:^{
        [PlayQueue.shared playSongWithPosition:index];
    }];
}

- (void)bassUpdateLockScreenInfo:(BassGaplessPlayer *)player {
	[PlayQueue.shared updateLockScreenInfo];
}

- (void)bassRetrySongAtOffsetInBytes:(NSInteger)bytes andSeconds:(NSInteger)seconds player:(BassGaplessPlayer*)player {
    [PlayQueue.shared startSongWithOffsetInBytes:bytes offsetInSeconds:seconds];
}

- (void)bassFailedToCreateNextStreamForIndex:(NSInteger)index player:(BassGaplessPlayer *)player {
    // The song ended, and we tried to make the next stream but it failed
    ISMSSong *song = [PlayQueue.shared songWithIndex:index];
    StreamHandler *handler = [StreamManager.shared handlerWithSong:song];
    if (!handler.isDownloading || handler.isDelegateNotifiedToStartPlayback) {
        // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
        [EX2Dispatch runInMainThreadAsync:^{
            [PlayQueue.shared playSongWithPosition:index];
        }];
    }
}

- (void)bassRetrievingOutputData:(BassGaplessPlayer *)player {
    [Social.shared playerHandleSocial];
}

@end
