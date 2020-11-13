//
//  EX2Macros.h
//  EX2Kit
//
//  Created by Ben Baron on 3/10/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef EX2Kit_Macros_h
#define EX2Kit_Macros_h

#define n2N(value) (value ? value : [NSNull null])

#define NSStringFromBOOL(value) (value ? @"YES" : @"NO")

#define BytesForSecondsAtBitrate(seconds, bitrate) ((bitrate / 8) * 1024 * seconds)

#define NSIndexPathMake(section, row) ([NSIndexPath indexPathForRow:row inSection:section])

#endif
