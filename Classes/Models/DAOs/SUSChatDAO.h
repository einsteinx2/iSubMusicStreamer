//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class SUSChatLoader;
@interface SUSChatDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate>

@property (strong) SUSChatLoader *loader;
@property (weak) NSObject <SUSLoaderDelegate> *delegate;

@property (strong) NSArray *chatMessages;

- (void)sendChatMessage:(NSString *)message;

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

@end
