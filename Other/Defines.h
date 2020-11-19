//
//  Defines.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Defines_h
#define iSub_Defines_h

#import "ISMSNotificationNames.h"

#define ISMSHeaderColor [UIColor colorWithRedInt:200 greenInt:200 blueInt:206 alpha:1]
#define ISMSHeaderTextColor [UIColor colorWithRedInt:77 greenInt:77 blueInt:77 alpha:1]
#define ISMSHeaderButtonColor [UIColor colorWithRedInt:0 greenInt:122 blueInt:255 alpha:1]

#ifdef BETA
    #ifdef SILENT
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
    #else
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
    #endif
#else
    #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#endif

#ifdef BETA
    #define LOG_LEVEL_ISUB_DEBUG static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
    #define LOG_LEVEL_ISUB_DEBUG static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#endif

#endif
