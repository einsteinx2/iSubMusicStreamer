//
//  SUSLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SUSLoaderDelegate.h"

@class SUSLoader;

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^SUSLoaderCallback)(BOOL success, NSError *error, SUSLoader *loader);

@interface SUSLoader : NSObject

@property (weak) NSObject<SUSLoaderDelegate> *delegate;
@property (copy) SUSLoaderCallback callbackBlock;

@property (readonly) ISMSLoaderType type;

@property (strong, readonly) NSData *receivedData;

+ (NSURLSession *)sharedSession;

- (void)setup; // Override this
- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate;
- (instancetype)initWithCallbackBlock:(LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;
- (NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)informDelegateLoadingFailed:(NSError *)error;
- (void)informDelegateLoadingFinished;

@end
