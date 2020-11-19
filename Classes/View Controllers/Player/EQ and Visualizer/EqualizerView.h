//
//  EqualizerPointView.h
//  iSub
//
//  Created by Ben Baron on 11/23/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "Defines.h"
#import "ISMSBassVisualType.h"

@interface EqualizerView : UIView

@property CGPoint location;
@property CGPoint previousLocation;

@property (strong) NSTimer *drawTimer;

@property ISMSBassVisualType visualType;


- (void)erase;
- (void)eraseBitBuffer;

- (void)changeType:(ISMSBassVisualType)type;
//- (void)changeType;
- (void)nextType;
- (void)prevType;

- (void)startEqDisplay;
- (void)stopEqDisplay;

@end
