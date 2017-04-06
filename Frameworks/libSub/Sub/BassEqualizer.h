//
//  BassEqualizer.h
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"
#import "bass_fx.h"
#import "BassParamEqValue.h"

@class BassParamEqValue;
@interface BassEqualizer : NSObject

@property (nonatomic, readonly) BOOL isEqActive;
@property (nonatomic) HCHANNEL channel;
@property (nonatomic) float gain;

- (id)initWithChannel:(HCHANNEL)theChannel;

- (void)clearEqualizerValues;
- (void)applyEqualizerValues;
- (void)applyEqualizerValues:(NSArray *)values;
- (void)updateEqParameter:(BassParamEqValue *)value;
- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value;
- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value;
- (void)removeAllEqualizerValues;
- (BOOL)toggleEqualizer;
- (NSArray *)equalizerValues;
- (void)createVolumeFx;

@end
