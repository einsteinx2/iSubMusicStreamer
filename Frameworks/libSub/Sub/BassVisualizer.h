//
//  BassVisualizer.h
//  Anghami
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

- (id)initWithChannel:(HCHANNEL)theChannel;

- (void)readAudioData;
- (short)lineSpecData:(NSUInteger)index;
- (float)fftData:(NSUInteger)index;

@end
