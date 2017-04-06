//
//  BassGaplessPlayer_Test.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/12.
//  Copyright (c) 2012 Einstein Times Two Software. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>
#import "BassGaplessPlayer.h"

@interface BassGaplessPlayer_Test : GHTestCase
@end

@implementation BassGaplessPlayer_Test

- (void)test_bytesToBufferForKiloBitrate
{
    NSArray *audioBitratesInKbitsSec = @[ @64, @128, @192, @250, @320, @630, @1200 ];
    NSArray *downloadSpeedsInKbitsSec = @[ @50, @100, @150, @200, @250, @400, @630, @1010];
    
    for (NSNumber *audioBitrate in audioBitratesInKbitsSec)
    {
        for (NSNumber *downloadSpeed in downloadSpeedsInKbitsSec)
        {
            NSUInteger minBytes = [BassGaplessPlayer bytesToBufferForKiloBitrate:audioBitrate.doubleValue speedInBytesPerSec:(downloadSpeed.unsignedIntegerValue * 128)];
            
            NSUInteger minSeconds = minBytes / (audioBitrate.unsignedIntegerValue * 128);
            
            GHTestLog(@"buffer bytes: %u (%u seconds)  for bitrate: %u   and speed: %u ", minBytes, minSeconds, audioBitrate.unsignedIntegerValue, downloadSpeed.unsignedIntegerValue);
        }
    }
}

@end
