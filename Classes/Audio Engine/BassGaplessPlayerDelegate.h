//
//  BassGaplessPlayerDelegate.h
//  iSub
//
//  Created by Ben Baron on 9/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ISMSSong, BassGaplessPlayer;
@protocol BassGaplessPlayerDelegate <NSObject>

@optional
- (void)bassSeekToPositionStarted:(BassGaplessPlayer*)player;
- (void)bassSeekToPositionSuccess:(BassGaplessPlayer*)player;
- (void)bassStopped:(BassGaplessPlayer*)player;
- (void)bassFirstStreamStarted:(BassGaplessPlayer*)player;
- (void)bassSongEndedCalled:(BassGaplessPlayer*)player;
- (void)bassFreed:(BassGaplessPlayer *)player;
- (void)bassUpdateLockScreenInfo:(BassGaplessPlayer *)player;
- (void)bassFailedToCreateNextStreamForIndex:(NSInteger)index player:(BassGaplessPlayer *)player;
- (void)bassRetrievingOutputData:(BassGaplessPlayer *)player;

@required
- (ISMSSong *)bassSongForIndex:(NSInteger)index player:(BassGaplessPlayer *)player;
- (NSInteger)bassIndexAtOffset:(NSInteger)offset fromIndex:(NSInteger)index player:(BassGaplessPlayer *)player;
- (NSInteger)bassCurrentPlaylistIndex:(BassGaplessPlayer *)player;
- (void)bassRetrySongAtIndex:(NSInteger)index player:(BassGaplessPlayer*)player;
- (void)bassRetrySongAtOffsetInBytes:(NSInteger)bytes andSeconds:(NSInteger)seconds player:(BassGaplessPlayer*)player;

@end
