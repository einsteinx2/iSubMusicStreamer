//
//  WBScrobbleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "WBScrobbleLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation WBScrobbleLoader

- (NSURLRequest *)createRequest
{
    NSURLRequest *request;
    NSString *eventType = self.isSubmission ? @"SUBMIT" : @"NOWPLAYING";

    if (self.isSubmission)
    {
        NSString *event = [NSString stringWithFormat:@"%@,%ld", self.aSong.songId, (long)[[NSDate date] timeIntervalSince1970]];
        ALog(@"scrobble event: %@", event);
        request = [NSMutableURLRequest requestWithPMSAction:@"scrobble"
                                                   parameters:@{
                                                                 @"event": event,
                                                                 @"action" : eventType
                                                             }];
    }
    else
    {
        request = [NSMutableURLRequest requestWithPMSAction:@"scrobble"
                                                 parameters:@{
                                                                @"id": self.aSong.songId,
                                                                @"action": eventType
                                                            }];
    }

    //ALog(@"%@", request);
    return request;
}

- (void)processResponse
{
    [self informDelegateLoadingFinished];
}

@end
