//
//  ISMSStreamHandler.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"

@class ISMSSong, EX2FileEncryptor;
@interface ISMSURLConnectionStreamHandler : ISMSStreamHandler <NSURLConnectionDelegate>

@property (strong) NSURLConnection *connection;
@property (strong) NSURLRequest *request;
@property (strong) NSThread *loadingThread;

@end
