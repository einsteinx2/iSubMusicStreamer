//
//  BassEqualizer.m
//  iSub
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassEqualizer.h"
#import "SavedSettings.h"
#import "Defines.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define ISMS_EqualizerGainReduction 0.45

@interface BassEqualizer() {
    HCHANNEL _channel;
    float _gain;
}
@property (nonatomic, strong) NSMutableArray *eqHandles;
@property (nonatomic, strong) NSMutableArray *eqValues;
@property HFX volumeFx;
@property HFX limiterFx;
@end

LOG_LEVEL_ISUB_DEFAULT

@implementation BassEqualizer

- (instancetype)init {
    if (self = [super init]) {
		_eqValues = [[NSMutableArray alloc] initWithCapacity:4];
		_eqHandles = [[NSMutableArray alloc] initWithCapacity:4];
	}
	return self;
}

- (instancetype)initWithChannel:(HCHANNEL)theChannel {
	if (self = [self init]) {
		[self setChannel:theChannel];
	}
	return self;
}

- (HCHANNEL)channel {
	return _channel;
}

- (void)setChannel:(HCHANNEL)theChannel {
	if (_channel != theChannel) {
		// Remove any EQ points
		[self removeAllEqualizerValues];
		
		// Set the channel
		_channel = theChannel;
	}
}

- (void)clearEqualizerValues {
	int i = 0;
	for (NSNumber *handle in self.eqHandles) {
		BASS_ChannelRemoveFX(self.channel, handle.unsignedIntValue);
		i++;
	}
	
    @synchronized(self.eqValues) {
        for (BassParamEqValue *value in self.eqValues) {
            value.handle = 0;
        }
    }
	
	//DLog(@"removed %i effect channels", i);
	[self.eqHandles removeAllObjects];
	_isEqActive = NO;
}

- (void)applyEqualizerValues {
	[self applyEqualizerValues:self.eqValues];
}

- (void)applyEqualizerValues:(NSArray *)values {
    if (values == nil) {
		return;
    } else if (values.count == 0) {
		return;
    }
	
    // Do this to prevent crash if array is mutated (not doing the whole for loop inside the sync block in case the BASS function deadlocks)
    NSArray *eqValuesTemp;
    @synchronized(self.eqValues) {
        eqValuesTemp = [NSArray arrayWithArray:self.eqValues];
    }
	
    for (BassParamEqValue *value in eqValuesTemp) {
		HFX handle = BASS_ChannelSetFX(self.channel, BASS_FX_DX8_PARAMEQ, 10);
		BASS_DX8_PARAMEQ p = value.parameters;
		BASS_FXSetParameters(handle, &p);
		
		value.handle = handle;
		
		[self.eqHandles addObject:@(handle)];
	}
	_isEqActive = YES;
}

- (void)updateEqParameter:(BassParamEqValue *)value {
    @synchronized(self.eqValues) {
        if (self.eqValues.count > value.arrayIndex) {
            [self.eqValues replaceObjectAtIndex:value.arrayIndex withObject:value];
        }
    }
	
	if (self.isEqActive) {
		BASS_DX8_PARAMEQ p = value.parameters;
		DDLogVerbose(@"[BassEqualizer] updating eq for handle: %i   new freq: %f   new gain: %f", value.handle, p.fCenter, p.fGain);
		BASS_FXSetParameters(value.handle, &p);
	}
}

- (BassParamEqValue *)addEqualizerValue:(BASS_DX8_PARAMEQ)value {
	NSInteger index;
    @synchronized(self.eqValues) {
        index = [self.eqValues count];
    }
	BassParamEqValue *eqValue = [[BassParamEqValue alloc] initWithParameters:value arrayIndex:index];
    
    @synchronized(self.eqValues) {
        [self.eqValues addObject:eqValue];
    }
	
	if (self.isEqActive) {
		HFX handle = BASS_ChannelSetFX(self.channel, BASS_FX_DX8_PARAMEQ, 10);
		BASS_FXSetParameters(handle, &value);
		eqValue.handle = handle;
		
		[self.eqHandles addObject:@(handle)];
	}
	
	return eqValue;
}

- (NSArray *)removeEqualizerValue:(BassParamEqValue *)value {
    NSLog(@"removeEqualizerValue");
	if (self.isEqActive) {
		// Disable the effect channel
		BASS_ChannelRemoveFX(self.channel, value.handle);
	}
	
	// Remove the handle
	[self.eqHandles removeObject:@(value.handle)];
	
	// Remove the value
    NSInteger count = 0;
    @synchronized(self.eqValues) {
        [self.eqValues removeObject:value];
        count = self.eqValues.count;
    }
    
	for (NSInteger i = value.arrayIndex; i < count; i++) {
		// Adjust the arrayIndex values for the other objects
		BassParamEqValue *aValue;
        @synchronized(self.eqValues) {
            aValue = self.eqValues[i];
        }
		aValue.arrayIndex = i;
	}
	
	return self.equalizerValues;
}

- (void)removeAllEqualizerValues {
	[self clearEqualizerValues];
	
    @synchronized(self.eqValues) {
        [self.eqValues removeAllObjects];
    }
	
	_isEqActive = NO;
}

- (BOOL)toggleEqualizer {
    settingsS.isEqualizerOn = !self.isEqActive;
    
	if (self.isEqActive) {
		[self clearEqualizerValues];
		self.gain = settingsS.gainMultiplier;
		return NO;
	} else {
        NSArray *eqValuesTemp;
        @synchronized(self.eqValues) {
            eqValuesTemp = [NSArray arrayWithArray:self.eqValues];
        }
		[self applyEqualizerValues:eqValuesTemp];
		self.gain = settingsS.gainMultiplier;
		return YES;
	}
}

- (NSArray *)equalizerValues {
    @synchronized(self.eqValues) {
        return [NSArray arrayWithArray:self.eqValues];
    }
}

- (void)createVolumeFx {
    if (self.volumeFx) {
        BASS_ChannelRemoveFX(self.channel, self.volumeFx);
    }
    
    // Enable BASS_FX plugin
    BASS_FX_GetVersion();
    
    self.volumeFx = BASS_ChannelSetFX(self.channel, BASS_FX_BFX_VOLUME, 50);
    self.gain = settingsS.gainMultiplier;
}

- (void)createLimiterFx {
    if (self.limiterFx) {
        BASS_ChannelRemoveFX(self.channel, self.limiterFx);
    }
    
    // Enable BASS_FX plugin
    BASS_FX_GetVersion();

    self.limiterFx = BASS_ChannelSetFX(self.channel, BASS_FX_BFX_COMPRESSOR2, 100);
    BASS_BFX_COMPRESSOR2 limiterParams;
    limiterParams.fGain = 0;       // extra output gain
    limiterParams.fRatio = 15;     // bottom end of limiter ratio range, 20 would be a hard brick wall limiter
    limiterParams.fAttack = 0.25;  // 0.25 ms
    limiterParams.fRelease = 0.25; // 0.25 ms
    limiterParams.fThreshold = -3; // -3 dB
    limiterParams.lChannel = BASS_BFX_CHANALL;
    BASS_FXSetParameters(self.channel, &limiterParams);
}

- (void)setGain:(float)theGain {
	_gain = theGain;
	
	CGFloat modifiedGainValue = self.isEqActive ? _gain - ISMS_EqualizerGainReduction : _gain;
	modifiedGainValue = modifiedGainValue < 0. ? 0. : modifiedGainValue;
	
	BASS_BFX_VOLUME volumeParamsInit = {0, modifiedGainValue};
	BASS_FXSetParameters(self.volumeFx, &volumeParamsInit);
}

- (float)gain {
	return _gain;
}

- (void)dealloc {
	[self removeAllEqualizerValues];
}

@end
