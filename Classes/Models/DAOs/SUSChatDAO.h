//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@class SUSChatLoader;
@interface SUSChatDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>

@property (strong) SUSChatLoader *loader;
@property (weak) NSObject <ISMSLoaderDelegate> *delegate;

@property (strong) NSArray *chatMessages;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;

- (void)sendChatMessage:(NSString *)message;

- (instancetype)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

@end
