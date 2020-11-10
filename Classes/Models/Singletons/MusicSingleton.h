//
//  MusicSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_MusicSingleton_h
#define iSub_MusicSingleton_h

#define musicS ((MusicSingleton *)[MusicSingleton sharedInstance])


@class ISMSSong;
@interface MusicSingleton : NSObject

@property BOOL isAutoNextNotificationOn;
@property (readonly) BOOL showPlayerIcon;

+ (id)sharedInstance;

- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds;
- (void)startSong;
- (ISMSSong *)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)prevSong;
- (void)resumeSong;
- (void)showPlayer;
- (void)updateLockScreenInfo;

@end

#endif