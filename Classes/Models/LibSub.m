//
//  LibSub.m
//  libSub
//
//  Created by Benjamin Baron on 11/24/12.
//  Copyright (c) 2012 Einstein Times Two Software. All rights reserved.
//

#import "LibSub.h"

@implementation LibSub

+ (BOOL)isWifi
{
    return [[EX2Reachability reachabilityForLocalWiFi] currentReachabilityStatus] == ReachableViaWiFi;
}

@end
