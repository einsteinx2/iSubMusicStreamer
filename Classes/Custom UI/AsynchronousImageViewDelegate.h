//
//  AsynchronousImageViewDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AsynchronousImageView;
@protocol AsynchronousImageViewDelegate <NSObject>
@optional
- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView;
- (void)asyncImageViewLoadingFailed:(AsynchronousImageView *)asyncImageView withError:(NSError *)error;
@end
