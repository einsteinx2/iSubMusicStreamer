//
//  BassGaplessPlayerDelegate.h
//  Anghami
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@class Song, BassGaplessPlayer;
@protocol BassGaplessPlayerDelegate <NSObject>

@optional
- (void)bassSeekToPositionStarted:(BassGaplessPlayer*)player;
- (void)bassSeekToPositionSuccess:(BassGaplessPlayer*)player;
- (void)bassStopped:(BassGaplessPlayer*)player;
- (void)bassFirstStreamStarted:(BassGaplessPlayer*)player;
- (void)bassSongEndedCalled:(BassGaplessPlayer*)player;
- (void)bassFreed:(BassGaplessPlayer *)player;
- (void)bassUpdateLockScreenInfo:(BassGaplessPlayer *)player;
- (void)bassFailedToCreateNextStreamForIndex:(NSUInteger)index player:(BassGaplessPlayer *)player;
- (void)bassRetrievingOutputData:(BassGaplessPlayer *)player;

@required
- (ISMSSong *)bassSongForIndex:(NSUInteger)index player:(BassGaplessPlayer *)player;
- (NSUInteger)bassIndexAtOffset:(NSInteger)offset fromIndex:(NSUInteger)index player:(BassGaplessPlayer *)player;
- (NSUInteger)bassCurrentPlaylistIndex:(BassGaplessPlayer *)player;
- (void)bassRetrySongAtIndex:(NSUInteger)index player:(BassGaplessPlayer*)player;
- (void)bassRetrySongAtOffsetInBytes:(NSUInteger)bytes andSeconds:(NSUInteger)seconds player:(BassGaplessPlayer*)player;

@end
