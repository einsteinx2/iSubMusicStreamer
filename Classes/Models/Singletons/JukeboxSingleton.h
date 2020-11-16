//
//  JukeboxSingleton.h
//  iSub
//
//  Created by Ben Baron on 2/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_JukeboxSingleton_h
#define iSub_JukeboxSingleton_h

#import <Foundation/Foundation.h>
//#import "EX2SimpleConnectionQueue.h"

#define jukeboxS ((JukeboxSingleton *)[JukeboxSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Jukebox)
@interface JukeboxSingleton : NSObject

@property BOOL isPlaying;
@property float gain;
//@property (strong) EX2SimpleConnectionQueue *connectionQueue;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

// Jukebox control methods
- (void)playSongAtPosition:(NSNumber *)position;
- (void)play;
- (void)stop;
- (void)skipPrev;
- (void)skipNext;
- (void)setVolume:(float)level;
- (void)addSong:(NSString*)songId;
- (void)addSongs:(NSArray*)songIds;
- (void)replacePlaylistWithLocal;
- (void)removeSong:(NSString*)songId;
- (void)clearPlaylist;
- (void)clearRemotePlaylist;
- (void)shuffle;
- (void)getInfo;

@end

NS_ASSUME_NONNULL_END

#endif
