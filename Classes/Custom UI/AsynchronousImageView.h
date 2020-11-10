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

@class SUSCoverArtDAO;
@interface AsynchronousImageView : UIImageView <SUSLoaderDelegate>

@property (weak) IBOutlet NSObject<AsynchronousImageViewDelegate> *delegate;
@property (copy) NSString *coverArtId;
@property (strong) SUSCoverArtDAO *coverArtDAO;
@property BOOL isLarge;
@property (strong) UIActivityIndicatorView *activityIndicator;

- (instancetype)initWithFrame:(CGRect)frame coverArtId:(NSString *)artId isLarge:(BOOL)large delegate:(NSObject<AsynchronousImageViewDelegate> *)theDelegate;

@end
