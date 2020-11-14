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

typedef enum {
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
} ISMSBassVisualType;

#define ISMSJukeboxTimeout 60.0

#define ISMSHeaderColor [UIColor colorWithRedInt:200 greenInt:200 blueInt:206 alpha:1]
#define ISMSHeaderTextColor [UIColor colorWithRedInt:77 greenInt:77 blueInt:77 alpha:1]
#define ISMSHeaderButtonColor [UIColor colorWithRedInt:0 greenInt:122 blueInt:255 alpha:1]

#define ISMSRegularFont(value) [UIFont fontWithName:@"HelveticaNeue" size:value]
#define ISMSBoldFont(value) [UIFont fontWithName:@"HelveticaNeue-Bold" size:value]

#define ISMSArtistFont ISMSRegularFont(16)
#define ISMSAlbumFont ISMSRegularFont(16)
#define ISMSSongFont ISMSRegularFont(16)

#define ISMSiPadBackgroundColor [UIColor colorWithRedInt:200 greenInt:200 blueInt:206 alpha:1]
#define ISMSiPadCornerRadius 5.

#define ISMSLoadingTimeout 240.0
#define ISMSJukeboxTimeout 60.0
#define ISMSServerCheckTimeout 15.0

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
