//
//  ISMSLoaderNew.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSLoaderNew.h"
#import "ISMSURLSessionDelegate.h"

@interface ISMSLoaderNew()
@property (strong) NSData *receivedData;
@property (nonatomic, strong) ISMSLoaderNew *selfRef;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@end

@implementation ISMSLoaderNew

static NSURLSession *_sharedSession = nil;
static ISMSURLSessionDelegate *_sharedSessionDelegate = nil;
static dispatch_once_t _sharedSessionDispatchOnce = 0;
+ (NSURLSession *)sharedSession {
    dispatch_once(&_sharedSessionDispatchOnce, ^{
        _sharedSessionDelegate = [[ISMSURLSessionDelegate alloc] init];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        _sharedSession = [NSURLSession sessionWithConfiguration:configuration delegate:_sharedSessionDelegate delegateQueue:nil];
    });
    return _sharedSession;
}

- (void)setup {
    // Optionally override in subclass
}

- (instancetype)initWithDelegate:(NSObject<ISMSLoaderDelegateNew> *)theDelegate {
    if (self = [super init]) {
        [self setup];
        _delegate = theDelegate;
    }
    
    return self;
}

- (instancetype)initWithCallbackBlock:(LoaderCallback)theBlock {
    if (self = [super init]) {
        [self setup];
        _callbackBlock = [theBlock copy];
    }
    
    return self;
}

- (ISMSLoaderType)type {
    return ISMSLoaderType_Generic;
}

- (void)startLoad {
    NSURLRequest *request = [self createRequest];
    if (!request) return;
    
    // Cancel any existing request
    [self cancelLoad];
    
    // Keep a strong reference to self to allow loading without saving a loader reference
    if (!self.selfRef) self.selfRef = self;
    
    // Load the API endpoint
    self.dataTask = [[self.class sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            // Inform the delegate that loading failed
            [self informDelegateLoadingFailed:error];
        } else {
            self.receivedData = data;
            
            DLog(@"loader type: %i response:\n%@", self.type, [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
            [self processResponse];
        }
    }];
    [self.dataTask resume];
}

- (void)cancelLoad {
    [self.dataTask cancel];
    [self cleanup];
}

- (void)cleanup {
    // Clean up the connection
    self.dataTask = nil;
    self.receivedData = nil;
    
    // Remove strong reference to self so the loader can deallocate
    self.selfRef = nil;
}

- (NSURLRequest *)createRequest {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (void)processResponse {
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)informDelegateLoadingFailed:(NSError *)error {
    [EX2Dispatch runInMainThreadAsync:^{
        if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)]) {
            [self.delegate loadingFailed:self withError:error];
        }
        
        if (self.callbackBlock) {
            self.callbackBlock(NO, error, self);
        }
        
        [self cleanup];
    }];
}

- (void)informDelegateLoadingFinished {
    [EX2Dispatch runInMainThreadAsync:^{
        if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
            [self.delegate loadingFinished:self];
            
        }

        if (self.callbackBlock) {
            self.callbackBlock(YES, nil, self);
        }

        [self cleanup];
    }];
}

@end
