//
//  ISMSStreamHandlerTest.m
//  iSub
//
//  Created by Benjamin Baron on 12/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>
#import "ISMSStreamHandler.h"

@interface ISMSStreamHandler_Test : GHTestCase
@end

@implementation ISMSStreamHandler_Test

- (void)test_minBytesToStartPlaybackForKiloBitrate
{
    NSArray *audioBitratesInKbitsSec = @[ @64, @128, @192, @250, @320, @630, @1200 ];
    NSArray *downloadSpeedsInKbitsSec = @[ @50, @150, @250, @400, @630, @1010, @2000, @4000 ];
    
    for (NSNumber *audioBitrate in audioBitratesInKbitsSec)
    {
        for (NSNumber *downloadSpeed in downloadSpeedsInKbitsSec)
        {
            NSUInteger minBytes = [ISMSStreamHandler minBytesToStartPlaybackForKiloBitrate:audioBitrate.doubleValue speedInBytesPerSec:(downloadSpeed.unsignedIntegerValue * 128)];
            
            NSUInteger minSeconds = minBytes / (audioBitrate.unsignedIntegerValue * 128);
                                    
            GHTestLog(@"minBytes: %u (%u seconds)  for bitrate: %u   and speed: %u ", minBytes, minSeconds, audioBitrate.unsignedIntegerValue, downloadSpeed.unsignedIntegerValue);
        }
    }
}

@end
