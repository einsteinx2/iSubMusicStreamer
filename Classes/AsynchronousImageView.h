//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

@protocol AsynchronousImageViewDelegate;
@class SUSCoverArtDAO;
@interface AsynchronousImageView : UIImageView <ISMSLoaderDelegate>

@property (weak) IBOutlet NSObject<AsynchronousImageViewDelegate> *delegate;
@property (copy) NSString *coverArtId;
@property (strong) SUSCoverArtDAO *coverArtDAO;
@property BOOL isLarge;
@property (strong) UIActivityIndicatorView *activityIndicator;

- (id)initWithFrame:(CGRect)frame coverArtId:(NSString *)artId isLarge:(BOOL)large delegate:(NSObject<AsynchronousImageViewDelegate> *)theDelegate;

@end
