//
//  ISMSPlayerView.h
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ISMSScrubberView.h"

@protocol ISMSPlayerViewDelegate <NSObject>

@end

@interface ISMSPlayerView : UIView <ISMSScrubberViewDelegate>

@property (nonatomic, weak) id<ISMSPlayerViewDelegate> delegate;
@property (strong) ISMSScrubberView *scrubberView;

@end
