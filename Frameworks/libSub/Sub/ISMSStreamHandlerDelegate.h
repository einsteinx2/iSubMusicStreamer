//
//  SUSStreamHandlerDelegate.h
//  Anghami
//
//  Created by Ben Baron on 11/13/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@class ISMSStreamHandler;
@protocol ISMSStreamHandlerDelegate <NSObject>

@optional
- (void)ISMSStreamHandlerStarted:(ISMSStreamHandler *)handler;
- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler;
- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler;
- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error;
- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSStreamHandler *)handler;
- (void)ISMSStreamHandlerPartialPrecacheUnpaused:(ISMSStreamHandler *)handler;

@end
