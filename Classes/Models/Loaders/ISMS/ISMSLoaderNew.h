//
//  ISMSLoaderNew.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ISMSLoaderDelegateNew.h"

@class ISMSLoaderNew;

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallbackNew)(BOOL success, NSError *error, ISMSLoaderNew *loader);

@interface ISMSLoaderNew : NSObject

@property (weak) NSObject<ISMSLoaderDelegateNew> *delegate;
@property (copy) LoaderCallbackNew callbackBlock;

@property (readonly) ISMSLoaderType type;

@property (strong, readonly) NSData *receivedData;

+ (NSURLSession *)sharedSession;

- (void)setup; // Override this
- (instancetype)initWithDelegate:(NSObject<ISMSLoaderDelegateNew> *)theDelegate;
- (instancetype)initWithCallbackBlock:(LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;
- (NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)informDelegateLoadingFailed:(NSError *)error;
- (void)informDelegateLoadingFinished;

@end
