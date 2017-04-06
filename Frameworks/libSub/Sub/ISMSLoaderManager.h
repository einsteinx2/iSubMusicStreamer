//
//  LoaderManager.h
//  iSub
//
//  Created by Ben Baron on 9/24/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@protocol ISMSLoaderManager <NSObject>

@required
- (id)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
