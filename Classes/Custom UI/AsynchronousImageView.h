//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AsynchronousImageViewDelegate.h"
#import "SUSLoaderDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class SUSCoverArtDAO;
@interface AsynchronousImageView : UIImageView <SUSLoaderDelegate>

@property (nullable, weak) IBOutlet NSObject<AsynchronousImageViewDelegate> *delegate;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, strong) SUSCoverArtDAO *coverArtDAO;
@property BOOL isLarge;
@property (nullable, strong) UIActivityIndicatorView *activityIndicator;

- (instancetype)initWithFrame:(CGRect)frame coverArtId:(nullable NSString *)artId isLarge:(BOOL)large delegate:(nullable NSObject<AsynchronousImageViewDelegate> *)theDelegate;

@end

NS_ASSUME_NONNULL_END
