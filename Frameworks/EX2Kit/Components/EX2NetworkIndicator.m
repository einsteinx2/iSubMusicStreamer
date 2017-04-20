//
//  EX2NetworkIndicator.h
//  iSub
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2NetworkIndicator.h"

static NSUInteger networkUseCount = 0;

@implementation EX2NetworkIndicator

+ (void)usingNetwork
{
	@synchronized(self)
	{
		networkUseCount++;
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	}
}

+ (void)doneUsingNetwork
{
	@synchronized(self)
	{
		if (networkUseCount > 0)
		{
			networkUseCount--;
			
			if (networkUseCount == 0)
				[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		}
	}
}

+ (void)goingOffline
{
	@synchronized(self)
	{
		networkUseCount = 0;
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
}

@end
