//
//  NSString-time.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+time.h"

@implementation NSString (time)

+ (NSString *)formatTime:(double)seconds
{	
	if (seconds <= 0)
		return @"0:00";

	NSUInteger roundedSeconds = floor(seconds);
	
	int mins = (int) roundedSeconds / 60;
	int secs = (int) roundedSeconds % 60;
	if (secs < 10)
		return [NSString stringWithFormat:@"%i:0%i", mins, secs];
	else
		return [NSString stringWithFormat:@"%i:%i", mins, secs];
}

+ (NSString *)formatTimeHoursMinutes:(double)seconds hideHoursIfZero:(BOOL)hideHoursIfZero
{
	if (seconds <= 0)
		return  hideHoursIfZero ? @"00m" : @"0h00m";
    
	NSUInteger roundedSeconds = floor(seconds);
	
    int hours = (int) roundedSeconds / 3600;
	int mins = (int) (roundedSeconds % 3600) / 60;
    if (hideHoursIfZero && hours == 0)
    {
        if (mins < 10)
            return [NSString stringWithFormat:@"0%im", mins];
        else
            return [NSString stringWithFormat:@"%im", mins];
    }
    else
    {
        if (mins < 10)
            return [NSString stringWithFormat:@"%ih0%im", hours, mins];
        else
            return [NSString stringWithFormat:@"%ih%im", hours, mins];
    }
}

+ (NSString *)formatTimeDecimalHours:(double)seconds
{
	if (seconds <= 0)
		return @"0:00";
    
    if (seconds < 3600.)
    {
        // For less than an hour, show 00:00 style
        return [self formatTime:seconds];
    }
	else
    {
        // For an hour or greater, show decimal format
        double hours = seconds / 60. / 60.;
        return [NSString stringWithFormat:@"%.1f %@", hours, NSLocalizedString(@"hrs", @"EX2Kit format time, hours string")];
    }
}

// Return the time since the date provided, formatted in English
+ (NSString *)relativeTime:(NSDate *)date
{
	NSTimeInterval timeSinceDate = [[NSDate date] timeIntervalSinceDate:date];
	NSInteger time;
	
	if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]])
	{
		return @"never";
	}
	if (timeSinceDate <= 60)
	{
		return @"just now";
	}
	else if (timeSinceDate > 60 && timeSinceDate <= 3600)
	{
		time = (NSInteger)(timeSinceDate / 60);
		
		if (time == 1)
			return @"1 minute ago";
		else
			return [NSString stringWithFormat:@"%ld minutes ago", (long)time];
	}
	else if (timeSinceDate > 3600 && timeSinceDate <= 86400)
	{
		time = (NSInteger)(timeSinceDate / 3600);
		
		if (time == 1)
			return @"1 hour ago";
		else
			return [NSString stringWithFormat:@"%ld hours ago", (long)time];
	}	
	else if (timeSinceDate > 86400 && timeSinceDate <= 604800)
	{
		time = (NSInteger)(timeSinceDate / 86400);
		
		if (time == 1)
			return @"1 day ago";
		else
			return [NSString stringWithFormat:@"%ld days ago", (long)time];
	}
	else if (timeSinceDate > 604800 && timeSinceDate <= 2629743.83)
	{
		time = (NSInteger)(timeSinceDate / 604800);
		
		if (time == 1)
			return @"1 week ago";
		else
			return [NSString stringWithFormat:@"%ld weeks ago", (long)time];
	}
	else if (timeSinceDate > 2629743.83)
	{
		time = (NSInteger)(timeSinceDate / 2629743.83);
		
		if (time == 1)
			return @"1 month ago";
		else
			return [NSString stringWithFormat:@"%ld months ago", (long)time];
	}
	
	return @"";
}

@end
