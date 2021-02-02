//
//  EqualizerValue.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassParamEqValue.h"

@implementation BassParamEqValue

- (instancetype)initWithParameters:(BASS_DX8_PARAMEQ)parameters handle:(HFX)handle arrayIndex:(NSInteger)index {
    if (self = [super init]) {
		_parameters = parameters;
		_handle = handle;
		_arrayIndex = index;
	}
	return self;
}

- (instancetype)initWithParameters:(BASS_DX8_PARAMEQ)params arrayIndex:(NSInteger)index {
    return [self initWithParameters:params handle:0 arrayIndex:index];
}

- (instancetype)initWithParameters:(BASS_DX8_PARAMEQ)params {
	return [self initWithParameters:params handle:0 arrayIndex:NSIntegerMax];
}

- (float)frequency {
	return _parameters.fCenter;
}

- (void)setFrequency:(float)frequency {
	_parameters.fCenter = frequency;
}

- (float)gain {
	return _parameters.fGain;
}

- (void)setGain:(float)gain {
	_parameters.fGain = gain;
}

- (float)bandwidth {
	return _parameters.fBandwidth;
}

- (void)setBandwidth:(float)bandwidth {
	_parameters.fBandwidth = bandwidth;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQMake(float center, float gain, float bandwidth) {
	BASS_DX8_PARAMEQ p;
	p.fCenter = center;
	p.fGain = gain;
	p.fBandwidth = bandwidth;
	return p;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQFromPoint(float percentX, float percentY, float bandwidth) {
	BASS_DX8_PARAMEQ p;
	p.fCenter = exp2f((percentX * RANGE_OF_EXPONENTS) + 5);
	p.fGain = (.5 - percentY) * (CGFloat)(MAX_GAIN * 2);;
	p.fBandwidth = bandwidth;
	return p;
}

- (NSUInteger)hash {
	return fabsf(self.parameters.fCenter) + fabsf(self.parameters.fGain) + fabsf(self.parameters.fBandwidth) + self.handle;
}

- (BOOL)isEqualToBassParamEqValue:(BassParamEqValue *)otherValue {
	if (self == otherValue) return YES;
	
	if (self.parameters.fCenter == otherValue.parameters.fCenter &&
		self.parameters.fGain == otherValue.parameters.fGain &&
		self.parameters.fBandwidth == otherValue.parameters.fBandwidth &&
		self.handle == otherValue.handle)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other
{
	if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToBassParamEqValue:other];
}

@end
