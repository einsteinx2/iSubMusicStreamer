//
//  BassWrapper.h
//  iSub
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "bassmix.h"
#import "bassflac.h"
#import "bassopus.h"
#import "basswv.h"
#import "bass_mpc.h"
#import "bass_ape.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BassStream.h"

@interface BassWrapper : NSObject

+ (NSInteger)bassOutputBufferLengthMillis;

+ (void)bassInit:(NSInteger)sampleRate;
+ (void)bassInit;

+ (void)logError;
+ (void)printChannelInfo:(HSTREAM)channel;
+ (NSString *)formatForChannel:(HCHANNEL)channel;
+ (NSString *)stringFromErrorCode:(NSInteger)errorCode;
+ (NSInteger)estimateKiloBitrate:(BassStream *)bassStream;

@end
