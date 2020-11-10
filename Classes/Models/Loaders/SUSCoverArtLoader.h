//
//  SUSCoverArtLoader.h
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSCoverArtLoader : SUSLoader

@property (copy) NSString *coverArtId;
@property (readonly) BOOL isCoverArtCached;
@property BOOL isLarge;

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large;
- (BOOL)downloadArtIfNotExists;

@end
