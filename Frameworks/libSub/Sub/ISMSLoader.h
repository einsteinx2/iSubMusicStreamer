//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallback)(BOOL success, NSError *error, ISMSLoader *loader);

@interface ISMSLoader : NSObject <NSURLConnectionDelegate>

@property (weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (copy) LoaderCallback callbackBlock;

@property (strong) NSURLConnection *connection;
@property (strong) NSURLRequest *request;
@property (strong) NSURLResponse *response;
@property (strong) NSMutableData *receivedData;
@property (readonly) ISMSLoaderType type;

+ (id)loader;
+ (id)loaderWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;
+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock;

- (void)setup; // Override this
- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate;
- (id)initWithCallbackBlock:(LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;
- (NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message;

- (void)informDelegateLoadingFailed:(NSError *)error;
- (void)informDelegateLoadingFinished;

@end

#import "ISMSLoaders.h"