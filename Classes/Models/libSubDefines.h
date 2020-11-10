//
//  LibSubDefines.h
//  Sub
//
//  Created by Benjamin Baron on 11/24/12.
//  Copyright (c) 2012 Einstein Times Two Software. All rights reserved.
//

#ifndef Sub_LibSubDefines_h
#define Sub_LibSubDefines_h

#import "ISMSNotificationNames.h"

typedef enum
{
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
} ISMSBassVisualType;

#define ISMSLoadingTimeout 240.0
#define ISMSJukeboxTimeout 60.0
#define ISMSServerCheckTimeout 15.0

#ifdef BETA
    #ifdef SILENT
        #define LOG_LEVEL_ISUB_DEFAULT static const int ddLogLevel = LOG_LEVEL_VERBOSE;
    #else
        #define LOG_LEVEL_ISUB_DEFAULT static const int ddLogLevel = LOG_LEVEL_VERBOSE;
    #endif
#else
    #define LOG_LEVEL_ISUB_DEFAULT static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#endif

#ifdef BETA
    #define LOG_LEVEL_ISUB_DEBUG static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
    #define LOG_LEVEL_ISUB_DEBUG static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#endif

#endif
