//
//  ISMSPlayerViewController.h
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ISMSPlayerView.h"

@interface ISMSPlayerViewController : UIViewController <ISMSPlayerViewDelegate>

@property (nonatomic, weak) ISMSPlayerView *playerView;

@end
