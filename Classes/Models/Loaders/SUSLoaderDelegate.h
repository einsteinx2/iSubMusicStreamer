//
//  SUSLoaderDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SUSLoader;
@protocol SUSLoaderDelegate <NSObject>

@required
- (void)loadingFailed:(SUSLoader *)loader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader *)loader;

@end
