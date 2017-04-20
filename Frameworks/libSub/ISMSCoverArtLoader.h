//
//  SUSCoverArtLoader.h
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

@class FMDatabase;
@interface ISMSCoverArtLoader : ISMSLoader

@property (copy) NSString *coverArtId;
@property (readonly) BOOL isCoverArtCached;
@property BOOL isLarge;

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate>*)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large;
- (BOOL)downloadArtIfNotExists;

@end
