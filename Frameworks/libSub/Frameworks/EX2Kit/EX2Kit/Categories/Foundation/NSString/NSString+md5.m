//
//  NSString-md5.m
//  EX2Kit
//
//  Created by Ben Baron on 4/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSString+md5.h"
#import <CommonCrypto/CommonDigest.h>


@implementation NSString (md5)

+ (NSString *) md5:(NSString *)str 
{
	if ([str length] > 0)
	{
		const char *cStr = [str UTF8String];
		unsigned char result[16];
		CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
		return [NSString stringWithFormat:
			@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3], 
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
		];
	}
	
	return @"";
}

- (NSString *) md5
{
	return [NSString md5:self];
}

@end
