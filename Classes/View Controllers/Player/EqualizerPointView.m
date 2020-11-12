//
//  EqualizerPointView.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "EqualizerPointView.h"
#import "BassParamEqValue.h"

#define myWidth 30
#define myHeight 30

@implementation EqualizerPointView
@synthesize frequency=_frequency, gain=_gain, handle=_handle, eqValue=_eqValue;

- (instancetype)initWithCGPoint:(CGPoint)point parentSize:(CGSize)size {
    if (self = [super initWithFrame:CGRectMake(0, 0, myWidth, myHeight)]) {
		_parentSize = size;
		self.center = point;
		
		_position.x = point.x / size.width;
		_position.y = point.y / size.height;
		_handle = 0;
		
		self.image = [UIImage imageNamed:@"eqView.png"];
		
		self.userInteractionEnabled = YES;
		
		BASS_DX8_PARAMEQ p = BASS_DX8_PARAMEQMake(_frequency, _gain, DEFAULT_BANDWIDTH);
		_eqValue = [[BassParamEqValue alloc] initWithParameters:p];
    }
    return self;
}

- (CGFloat)percentXFromFrequency:(NSUInteger)frequency {
	return (log2(frequency) - 5) / 9;
}

- (CGFloat)percentYFromGain:(CGFloat)gain {
	return .5 - (gain / (CGFloat)(MAX_GAIN * 2));
}

- (instancetype)initWithEqValue:(BassParamEqValue *)value parentSize:(CGSize)size {
    if (self = [super initWithFrame:CGRectMake(0, 0, myWidth, myHeight)]) {
		_parentSize = size;
		
		CGFloat x = size.width * [self percentXFromFrequency:value.parameters.fCenter];
		CGFloat y = size.height * [self percentYFromGain:value.parameters.fGain];
		self.center = CGPointMake(x, y);
		
        _position.x = [self percentXFromFrequency:value.parameters.fCenter];
		_position.y = [self percentYFromGain:value.parameters.fGain];
		
		self.image = [UIImage imageNamed:@"eqView.png"];
		
		self.userInteractionEnabled = YES;
		
		self.eqValue = value;
    }
    return self;
}

- (void)setCenter:(CGPoint)center
{
	[super setCenter:center];
	
	_position.x = self.center.x / self.parentSize.width;
	_position.y = self.center.y / self.parentSize.height;
}

- (NSUInteger)frequency {
	return exp2f((self.position.x * RANGE_OF_EXPONENTS) + 5);
}

- (CGFloat)gain {
	return (.5 - self.position.y) * (CGFloat)(MAX_GAIN * 2);
}

- (HFX)handle {
	return self.eqValue.handle;
}

- (void)setEqValue:(BassParamEqValue *)value {
	_eqValue = value;
}

- (BassParamEqValue *)eqValue {
	_eqValue.gain = self.gain;
	_eqValue.frequency = self.frequency;
	_eqValue.bandwidth = DEFAULT_BANDWIDTH;
	
	return _eqValue;
}

- (NSComparisonResult)compare:(EqualizerPointView *)otherObject  {
	// Return ordered same if now the same class as me
	if(![otherObject isKindOfClass:[EqualizerPointView class]]) return NSOrderedSame;
		
	CGFloat myX = self.frame.origin.x;
	CGFloat otherX = otherObject.frame.origin.x;
	
	if (myX < otherX) return NSOrderedAscending;
	if (myX > otherX) return NSOrderedDescending;
	
	return NSOrderedSame;
}

/*CGFloat percentXFromFrequency(NSUInteger frequency)
{
	return (log2(frequency) - 5) / 9;
}

CGFloat percentYFromGain(CGFloat gain)
{
	return .5 - (gain / (CGFloat)(MAX_GAIN * 2));
}
 
CGPoint CGPointMakeFromEqValues(NSUInteger frequency, CGFloat gain)
{
	return CGPointMake(percentXFromFrequency(frequency), percentYFromGain(gain));
}*/

@end
