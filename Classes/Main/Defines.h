//
//  Defines.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Defines_h
#define iSub_Defines_h

#import <Foundation/Foundation.h>

#ifdef BETA
    // Log everything in beta builds unless SILENT is enabled, then log nothing (NSLogs and files using LOG_LEVEL_ISUB_DEBUG only)
    #ifdef SILENT
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelOff;
    #else
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelInfo;//DDLogLevelAll;
    #endif
#else
    // Only log DDLogInfo, DDLogWarning, and DDLogError in release builds for privacy and to reduce log spam for every API call
    #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif

// Log everything even on release builds
#define LOG_LEVEL_ISUB_DEBUG static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

// Helper functions
#define n2N(value) (value ? value : [NSNull null])
#define NSStringFromBOOL(value) (value ? @"YES" : @"NO")
#define BytesForSecondsAtBitrate(seconds, bitrate) ((bitrate / 8) * 1024 * seconds)
#define NSIndexPathMake(section, row) ([NSIndexPath indexPathForRow:row inSection:section])

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallback)(BOOL success, NSError * _Nullable error);

#endif
