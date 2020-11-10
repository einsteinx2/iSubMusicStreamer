//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLoader.h"
#import "NSMutableURLRequest+SUS.h"

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
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal object:nil];
	}
	return self;
}

- (instancetype)initWithCallbackBlock:(LoaderCallback)theBlock coverArtId:(NSString *)artId isLarge:(BOOL)large {
	if ((self = [super initWithCallbackBlock:theBlock])) {
		_isLarge = large;
		_coverArtId = [artId copy];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ISMSLoaderType)type {
    return ISMSLoaderType_CoverArt;
}

#pragma mark - Properties

- (FMDatabaseQueue *)dbQueue {
	if (self.isLarge) {
		return IS_IPAD() ? databaseS.coverArtCacheDb540Queue : databaseS.coverArtCacheDb320Queue;
	} else {
		return databaseS.coverArtCacheDb60Queue;
	}
}

- (BOOL)isCoverArtCached {
	return [self.dbQueue stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [self.coverArtId md5]] ? YES : NO;
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
            if (![self isCoverArtCached]) {
                if (![_loadingImageNames containsObject:self.coverArtId]) {
                    // This art is not loading, so start loading it
                    [_loadingImageNames addObject:self.coverArtId];
                    NSString *size = nil;
                    if (self.isLarge) {
                        if (IS_IPAD()) {
                            size = SCREEN_SCALE() == 2.0 ? @"1080" : @"540";
                        } else {
                            size = SCREEN_SCALE() == 2.0 ? @"640" : @"320";
                        }
                    } else {
                        size = SCREEN_SCALE() == 2.0 ? @"120" : @"60";
                    }
                    
                    return [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" parameters:@{@"id": n2N(self.coverArtId), @"size": n2N(size)}];
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
    if([UIImage imageWithData:self.receivedData]) {
        DLog(@"art loading completed for: %@", self.coverArtId);
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [self.coverArtId md5], self.receivedData];
        }];
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:self.coverArtId];
    } else {
        DLog(@"art loading failed for: %@", self.coverArtId);
        
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
    
//    [super informDelegateLoadingFailed:error];
}

#pragma mark - Internal Notifications

- (void)coverArtDownloadFinished:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[NSString class]]) {
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
    if ([notification.object isKindOfClass:[NSString class]]) {
        if ([self.coverArtId isEqualToString:notification.object]) {
            // My art download failed, so notify my delegate
            [self informDelegateLoadingFailed:nil];
        }
    }
}

@end
