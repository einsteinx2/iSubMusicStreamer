//
//  SUSLoaderManager.h
//  iSub
//
//  Created by Ben Baron on 9/24/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@protocol SUSLoaderManager <NSObject>

@required
//- (instancetype)initWithDelegate:(NSObject <SUSLoaderDelegate> *)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
