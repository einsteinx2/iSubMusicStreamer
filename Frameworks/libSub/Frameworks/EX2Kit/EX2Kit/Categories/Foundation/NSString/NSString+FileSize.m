//
//  NSString+FileSize.m
//  EX2Kit
//
//  Created by Ben Baron on 2/7/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSString+FileSize.h"

@implementation NSString (FileSize)

+ (NSString *)formatFileSize:(unsigned long long)size
{
	if (size < 1024)
	{
		return [NSString stringWithFormat:@"%qu bytes", size];
	}
	else if (size >= 1024 && size < 1048576)
	{
		return [NSString stringWithFormat:@"%.02f KB", ((double)size / 1024)];
	}
	else if (size >= 1048576 && size < 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f MB", ((double)size / 1024 / 1024)];
	}
	else if (size >= 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f GB", ((double)size / 1024 / 1024 / 1024)];
	}
	
	return @"";
}

- (unsigned long long)fileSizeFromFormat
{	
	// Extract the number value from the string
	NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
	NSArray *numbersArray = [self componentsSeparatedByCharactersInSet:set];
	NSString *pureNumbers = [numbersArray componentsJoinedByString:@""];
	double fileSize = [pureNumbers doubleValue];
	
	// Extract the size multiplier and apply it if necessary
	NSArray *sizes = @[@"k", @(1024), @"m", @(1024*1024), @"g", @(1024*1024*1024)];
	for (int i = 0; i < [sizes count]; i+=2)
	{
		NSString *sizeString = [sizes objectAtIndex:i];
		double sizeMultiplier = [[sizes objectAtIndex:i+1] unsignedLongLongValue];
		NSRange range = [[self lowercaseString] rangeOfString:sizeString options:NSBackwardsSearch];
		if (range.location != NSNotFound)
		{
			// Found this size, so apply it
			fileSize *= sizeMultiplier;
			break;
		}
	}
	
	return (unsigned long long)fileSize;
}

@end
