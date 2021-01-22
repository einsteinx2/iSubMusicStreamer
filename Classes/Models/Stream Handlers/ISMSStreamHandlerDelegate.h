//
//  SUSStreamHandlerDelegate.h
//  iSub
//
//  Created by Ben Baron on 11/13/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ISMSAbstractStreamHandler;

NS_ASSUME_NONNULL_BEGIN

@protocol ISMSStreamHandlerDelegate <NSObject>

@optional
- (void)ISMSStreamHandlerStarted:(ISMSAbstractStreamHandler *)handler;
- (void)ISMSStreamHandlerStartPlayback:(ISMSAbstractStreamHandler *)handler;
- (void)ISMSStreamHandlerConnectionFinished:(ISMSAbstractStreamHandler *)handler;
- (void)ISMSStreamHandlerConnectionFailed:(ISMSAbstractStreamHandler *)handler withError:(nullable NSError *)error;
- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSAbstractStreamHandler *)handler;
- (void)ISMSStreamHandlerPartialPrecacheUnpaused:(ISMSAbstractStreamHandler *)handler;

@end

NS_ASSUME_NONNULL_END
