//
//  ISMSLoaderDelegateNew.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ISMSLoaderNew;
@protocol ISMSLoaderDelegateNew <NSObject>

@required
- (void)loadingFailed:(ISMSLoaderNew *)loader withError:(NSError *)error;
- (void)loadingFinished:(ISMSLoaderNew *)loader;

@end
