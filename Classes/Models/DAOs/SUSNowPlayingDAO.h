//
//  SUSNowPlayingDAO.h
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class SUSNowPlayingLoader, ISMSSong;
@interface SUSNowPlayingDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (weak) id<SUSLoaderDelegate> delegate;
@property (strong) SUSNowPlayingLoader *loader;

@property (strong) NSArray *nowPlayingSongDicts;

@property (readonly) NSUInteger count;

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

- (ISMSSong *)songForIndex:(NSUInteger)index;
- (NSString *)playTimeForIndex:(NSUInteger)index;
- (NSString *)usernameForIndex:(NSUInteger)index;
- (NSString *)playerNameForIndex:(NSUInteger)index;
- (ISMSSong *)playSongAtIndex:(NSUInteger)index;

@end
