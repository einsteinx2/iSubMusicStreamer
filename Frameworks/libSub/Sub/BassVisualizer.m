//
//  BassVisualizer.m
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassVisualizer.h"

@interface BassVisualizer()
{
	float *_fftData;
	short *_lineSpecBuf;
	int _lineSpecBufSize;
}
@end

@implementation BassVisualizer

- (id)init
{
	if ((self = [super init]))
	{		
		if (SCREEN_SCALE() == 1.0)// && !IS_IPAD())
			_lineSpecBufSize = 256 * sizeof(short);
		else
			_lineSpecBufSize = 512 * sizeof(short);
		_lineSpecBuf = malloc(_lineSpecBufSize);
		
		_fftData = malloc(sizeof(float) * 1024);
	}
	return self;
}

- (id)initWithChannel:(HCHANNEL)theChannel
{
	if ((self = [self init]))
	{
		_channel = theChannel;
	}
	return self;
}

- (void)dealloc
{
	free(_lineSpecBuf);
	free(_fftData);
}

- (float)fftData:(NSUInteger)index
{
	@synchronized(self)
	{
		return _fftData[index];
	}
}

- (short)lineSpecData:(NSUInteger)index
{
	@synchronized(self)
	{
		return _lineSpecBuf[index];
	}
}

- (void)readAudioData
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	dispatch_async(queue, ^{
		@synchronized(self)
		{
			if (!_channel)
				return;
			
			// Get the FFT data for visualizer
			if (self.type == BassVisualizerTypeFFT)
				BASS_ChannelGetData(self.channel, _fftData, BASS_DATA_FFT2048);
			
			// Get the data for line spec visualizer
			if (self.type == BassVisualizerTypeLine)
				BASS_ChannelGetData(self.channel, _lineSpecBuf, _lineSpecBufSize);
		}
	});
}

@end
