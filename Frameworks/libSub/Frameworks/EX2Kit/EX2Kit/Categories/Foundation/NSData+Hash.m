//
//  NSData+Hash.m
//  EX2Kit
//
//  Created by Benjamin Baron on 3/29/13.
//
//

#import "NSData+Hash.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (Hash)

- (NSString *)sha1
{
    if (self.length == 0)
		return nil;
	
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1(self.bytes, (CC_LONG)self.length, digest);
	
	NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
	
	for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		[output appendFormat:@"%02x", digest[i]];
	
	return output;
}

- (NSString *)md5
{
    if (self.length == 0)
		return nil;
	
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
	CC_MD5(self.bytes, (CC_LONG)self.length, digest);
	
	NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
	
	for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		[output appendFormat:@"%02x", digest[i]];
	
	return output;
}

@end
