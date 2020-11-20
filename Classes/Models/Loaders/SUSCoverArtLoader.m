//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Defines.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation SUSCoverArtLoader

static NSMutableArray *_loadingImageNames;
static NSObject *_syncObject;

__attribute__((constructor))
static void initialize_navigationBarImages() {
	_loadingImageNames = [[NSMutableArray alloc] init];
	_syncObject = [[NSObject alloc] init];
}

#define ISMSNotification_CoverArtFinishedInternal @"ISMS cover art finished internal notification"
#define ISMSNotification_CoverArtFailedInternal @"ISMS cover art failed internal notification"

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate>*)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large {
	if ((self = [super initWithDelegate:delegate])) {
		_isLarge = large;
		_coverArtId = [artId copy];
		
		[NSNotificationCenter addObserverOnMainThread:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal];
		[NSNotificationCenter addObserverOnMainThread:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal];
	}
	return self;
}

- (instancetype)initWithCallbackBlock:(SUSLoaderCallback)theBlock coverArtId:(NSString *)artId isLarge:(BOOL)large {
	if ((self = [super initWithCallbackBlock:theBlock])) {
		_isLarge = large;
		_coverArtId = [artId copy];
		
		[NSNotificationCenter addObserverOnMainThread:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal];
		[NSNotificationCenter addObserverOnMainThread:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal];
	}
	return self;
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (SUSLoaderType)type {
    return SUSLoaderType_CoverArt;
}

#pragma mark - Properties

- (FMDatabaseQueue *)dbQueue {
	if (self.isLarge) {
		return UIDevice.isIPad ? databaseS.coverArtCacheDb540Queue : databaseS.coverArtCacheDb320Queue;
	} else {
		return databaseS.coverArtCacheDb60Queue;
	}
}

- (BOOL)isCoverArtCached {
	return [self.dbQueue stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", self.coverArtId.md5] ? YES : NO;
}

#pragma mark - Data loading

- (BOOL)downloadArtIfNotExists {
	if (self.coverArtId) {
		if (![self isCoverArtCached]) {
			[self startLoad];
			return YES;
		}
	}
	return NO;
}

- (NSURLRequest *)createRequest {
    @synchronized(_syncObject) {
        if (self.coverArtId && !settingsS.isOfflineMode) {
            if (!self.isCoverArtCached) {
                if (![_loadingImageNames containsObject:self.coverArtId]) {
                    // This art is not loading, so start loading it
                    [_loadingImageNames addObject:self.coverArtId];
                    CGFloat scale = UIScreen.mainScreen.scale;
                    CGFloat size = 0.0;
                    if (self.isLarge) {
                        if (UIDevice.isIPad) {
                            size = scale * 1080;
                        } else {
                            size = scale * 640;
                        }
                    } else {
                        size = scale * 80;
                    }
                    NSString *sizeString = [NSString stringWithFormat:@"%d", (int)size];
                    return [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" parameters:@{@"id": self.coverArtId, @"size": sizeString}];
                }
            }
        }
    }
    return nil;
}

- (void)processResponse {
    @synchronized(_syncObject) {
        [_loadingImageNames removeObject:self.coverArtId];
    }
    
    // Check to see if the data is a valid image. If so, use it; if not, use the default image.
    if ([UIImage imageWithData:self.receivedData]) {
        DDLogVerbose(@"art loading completed for: %@", self.coverArtId);
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", self.coverArtId.md5, self.receivedData];
        }];
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:self.coverArtId];
    } else {
        DDLogVerbose(@"art loading failed for: %@", self.coverArtId);
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:self.coverArtId];
    }
}

- (void)cancelLoad {
    [super cancelLoad];
    @synchronized(_syncObject) {
        [_loadingImageNames removeObject:self.coverArtId];
    }
}

- (void)informDelegateLoadingFailed:(NSError *)error {
    @synchronized(_syncObject) {
        [_loadingImageNames removeObject:self.coverArtId];
    }
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:self.coverArtId];
}

#pragma mark - Internal Notifications

- (void)coverArtDownloadFinished:(NSNotification *)notification {
    if ([notification.object isKindOfClass:NSString.class]) {
        if ([self.coverArtId isEqualToString:notification.object]) {
            // We can get deallocated inside informDelegateLoadingFinished, so grab the isLarge BOOL now
            BOOL large = self.isLarge;
            
            // My art download finished, so notify my delegate
            [self informDelegateLoadingFinished];
            
            if (large) {
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
            }
        }
    }
}

- (void)coverArtDownloadFailed:(NSNotification *)notification {
    if ([notification.object isKindOfClass:NSString.class]) {
        if ([self.coverArtId isEqualToString:notification.object]) {
            // My art download failed, so notify my delegate
            [self informDelegateLoadingFailed:nil];
        }
    }
}

@end
