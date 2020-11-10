//
//  ISMSScrubberView.h
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ISMSScrubberView;
@protocol ISMSScrubberViewDelegate <NSObject>

@optional
- (void)scrubber:(ISMSScrubberView *)scrubber didChangeElapsedPercentage:(double)elapsedPercentage;

@end

@interface ISMSScrubberView : UIView

@property (nonatomic, weak) id<ISMSScrubberViewDelegate> delegate;
@property double elapsedPercentage;

@end
