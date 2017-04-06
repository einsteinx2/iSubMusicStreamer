//
//  NSDate+UTC.m
//  EX2Kit
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSDate+UTC.h"

@implementation NSDate (UTC)

- (NSString *)utcString
{
	static NSDateFormatter *dateFormatter = nil;
	@synchronized(self.class)
	{
		if (!dateFormatter)
		{
			dateFormatter = [[NSDateFormatter alloc] init];
			dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
			dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
		}
	}
	return [dateFormatter stringFromDate:self];
}

@end
