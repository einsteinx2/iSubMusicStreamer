//
//  SUSLoaderDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SUSLoader;
@protocol SUSLoaderDelegate <NSObject>

@required
- (void)loadingFailed:(nullable SUSLoader *)loader withError:(nullable NSError *)error;
- (void)loadingFinished:(nullable SUSLoader *)loader;

@end

NS_ASSUME_NONNULL_END
