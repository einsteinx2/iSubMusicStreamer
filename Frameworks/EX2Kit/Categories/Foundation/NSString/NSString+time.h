//
//  NSString-time.h
//  EX2Kit
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@interface NSString (time)

+ (NSString *)formatTime:(double)seconds;
+ (NSString *)formatTimeHoursMinutes:(double)seconds hideHoursIfZero:(BOOL)hideHoursIfZero;
+ (NSString *)formatTimeDecimalHours:(double)seconds;
+ (NSString *)relativeTime:(NSDate *)date;

@end
