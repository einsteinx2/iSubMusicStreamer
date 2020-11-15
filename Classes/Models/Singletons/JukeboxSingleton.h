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

@property BOOL jukeboxIsPlaying;
@property float jukeboxGain;
//@property (strong) EX2SimpleConnectionQueue *connectionQueue;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

// Jukebox control methods
- (void)jukeboxPlaySongAtPosition:(NSNumber *)position;
- (void)jukeboxPlay;
- (void)jukeboxStop;
- (void)jukeboxPrevSong;
- (void)jukeboxNextSong;
- (void)jukeboxSetVolume:(float)level;
- (void)jukeboxAddSong:(NSString*)songId;
- (void)jukeboxAddSongs:(NSArray*)songIds;
- (void)jukeboxReplacePlaylistWithLocal;
- (void)jukeboxRemoveSong:(NSString*)songId;
- (void)jukeboxClearPlaylist;
- (void)jukeboxClearRemotePlaylist;
- (void)jukeboxShuffle;
- (void)jukeboxGetInfo;

@end

NS_ASSUME_NONNULL_END

#endif
