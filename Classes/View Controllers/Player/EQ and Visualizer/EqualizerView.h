//
//  EqualizerPointView.h
//  iSub
//
//  Created by Ben Baron on 11/23/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Defines.h"
#import "ISMSBassVisualType.h"

@interface EqualizerView : UIView

@property CGPoint location;
@property CGPoint previousLocation;
@property (strong) NSTimer *drawTimer;
@property ISMSBassVisualType visualType;

- (void)changeType:(ISMSBassVisualType)type;
- (void)nextType;
- (void)prevType;

- (void)startEqDisplay;
- (void)stopEqDisplay;

@end
