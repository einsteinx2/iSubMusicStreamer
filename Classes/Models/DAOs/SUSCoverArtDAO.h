//
//  SUSCoverArtDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderManager.h"

NS_ASSUME_NONNULL_BEGIN

@class FMDatabase, SUSCoverArtLoader;
NS_SWIFT_NAME(CoverArtDAO)
@interface SUSCoverArtDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (nullable, weak) NSObject<SUSLoaderDelegate> *delegate;
@property (nullable, strong) SUSCoverArtLoader *loader;

@property (nullable, copy) NSString *coverArtId;
@property BOOL isLarge;

+ (UIImage *)defaultCoverArtImage:(BOOL)isLarge;
- (UIImage *)defaultCoverArtImage;
- (UIImage *)coverArtImage;
@property (readonly) BOOL isCoverArtCached;

- (instancetype)initWithDelegate:(nullable NSObject<SUSLoaderDelegate> *)theDelegate;
- (instancetype)initWithDelegate:(nullable NSObject<SUSLoaderDelegate> *)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large;

- (void)downloadArtIfNotExists;

@end

NS_ASSUME_NONNULL_END
