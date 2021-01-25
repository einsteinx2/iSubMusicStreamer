//
//  BassVisualizer.h
//  iSub
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "bass.h"

typedef enum
{
	BassVisualizerTypeNone = 0,
	BassVisualizerTypeFFT,
	BassVisualizerTypeLine
} BassVisualizerType;

@interface BassVisualizer : NSObject

@property BassVisualizerType type;
@property HSTREAM channel;

- (instancetype)initWithChannel:(HCHANNEL)theChannel;

- (void)readAudioData;
- (short)lineSpecData:(NSInteger)index;
- (float)fftData:(NSInteger)index;

@end
