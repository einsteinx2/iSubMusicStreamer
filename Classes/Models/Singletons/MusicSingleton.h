//
//  MusicSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_MusicSingleton_h
#define iSub_MusicSingleton_h

#import <Foundation/Foundation.h>

#define musicS ((MusicSingleton *)[MusicSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

@class ISMSSong;
NS_SWIFT_NAME(Music)
@interface MusicSingleton : NSObject

@property BOOL isAutoNextNotificationOn;
@property (readonly) BOOL showPlayerIcon;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)startSongAtOffsetInBytes:(unsigned long long)bytes andSeconds:(double)seconds;
- (void)startSong;
- (nullable ISMSSong *)playSongAtPosition:(NSInteger)position;
- (void)nextSong;
- (void)prevSong;
- (void)resumeSong;
- (void)showPlayer;
- (void)updateLockScreenInfo;

@end

NS_ASSUME_NONNULL_END

#endif
