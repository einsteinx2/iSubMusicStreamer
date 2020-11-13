//
//  SUSChatDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatDAO.h"
#import "SUSChatLoader.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "EX2Kit.h"

@implementation SUSChatDAO

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate {
    if (self = [super init]) {
		_delegate = theDelegate;
    }    
    return self;
}

- (void)dealloc {
	[_loader cancelLoad];
	_loader.delegate = nil;
}

#pragma mark - Public DAO Methods

- (void)sendChatMessage:(NSString *)message
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"addChatMessage" parameters:@{@"message": n2N(message)}];
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [EX2Dispatch runInMainThreadAsync:^{
            if (error) {
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotSendChatMessage extraAttributes:@{@"message": message}];
                [self.delegate loadingFailed:nil withError:error];
            } else {
                [self startLoad];
            }
        }];
    }];
    [dataTask resume];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSChatLoader alloc] initWithDelegate:self];
    [self.loader startLoad];
}

- (void)cancelLoad {
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)]) {
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader *)theLoader {
	self.chatMessages = [NSArray arrayWithArray:self.loader.chatMessages];
	
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
		[self.delegate loadingFinished:nil];
	}
}

@end
