//
//  SUSCoverArtLargeDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtDAO.h"
#import "SUSCoverArtLoader.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation SUSCoverArtDAO

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate {
	if ((self = [super init])) {
		_delegate = theDelegate;
	}
	return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate coverArtId:(NSString *)artId isLarge:(BOOL)large {
	if ((self = [super init])) {
		_delegate = theDelegate;
		_isLarge = large;
		_coverArtId = [artId copy];
	}
	return self;
}

- (void)dealloc {
	[_loader cancelLoad];
	_loader.delegate = nil;
}

#pragma mark - Public DAO methods

+ (UIImage *)defaultCoverArtImage:(BOOL)isLarge {
    return isLarge ? [UIImage imageNamed:@"default-album-art"] : [UIImage imageNamed:@"default-album-art-small"];
}

- (UIImage *)defaultCoverArtImage {
    return [self.class defaultCoverArtImage:self.isLarge];
}

- (UIImage *)coverArtImage {
    return [Store.shared coverArtWithId:self.coverArtId isLarge:self.isLarge].image ?: self.defaultCoverArtImage;
}

- (BOOL)isCoverArtCached {
	if (!self.coverArtId) return NO;
    return [Store.shared isCoverArtCachedWithId:self.coverArtId isLarge:self.isLarge];
}

- (void)downloadArtIfNotExists {
	if (self.coverArtId && !self.isCoverArtCached) {
		[self startLoad];
	}
}

#pragma mark - Loader Manager Methods

- (void)restartLoad {
	[self cancelLoad];
    [self startLoad];
}

- (void)startLoad {
    [self cancelLoad];
    self.loader = [[SUSCoverArtLoader alloc] initWithDelegate:self coverArtId:self.coverArtId isLarge:self.isLarge];
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
	self.loader.delegate = nil;
	self.loader = nil;
    
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
		[self.delegate loadingFinished:nil];
	}
}

@end
