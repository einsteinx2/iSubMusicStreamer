//
//  NSString-hex.m
//  EX2Kit
//
//  Created by Ben Baron on 10/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSString+hex.h"

@implementation NSString (hex)

+ (NSString *) stringFromHex:(NSString *)str 
{	
	NSMutableData *stringData = [[NSMutableData alloc] init];
	unsigned char whole_byte;
	char byte_chars[3] = {'\0','\0','\0'};
	int i;
	for (i=0; i < [str length] / 2; i++) {
		byte_chars[0] = [str characterAtIndex:i*2];
		byte_chars[1] = [str characterAtIndex:i*2+1];
		whole_byte = strtol(byte_chars, NULL, 16);
		[stringData appendBytes:&whole_byte length:1]; 
	}
	
	return [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
}

/*+ (NSString *) stringToHex:(NSString *)str
{	
	NSUInteger len = [str length];
	unichar *chars = malloc(len * sizeof(unichar));
	[str getCharacters:chars];
	
	NSMutableString *hexString = [[NSMutableString alloc] init];
	
	for(NSUInteger i = 0; i < len; i++ )
	{
		[hexString appendString:[NSString stringWithFormat:@"%x", chars[i]]];
	}
	free(chars);
		
	return [hexString autorelease];
}*/

// There is a problem with your stringToHex method - it drops leading 0s, and ignores 00s. Just as a quick fix, I made the below:
+ (NSString *) stringToHex:(NSString *)str
{   
    NSUInteger len = [str length];
    unichar *chars = malloc(len * sizeof(unichar));
    [str getCharacters:chars];
	
    NSMutableString *hexString = [[NSMutableString alloc] init];
	
    for(NSUInteger i = 0; i < len; i++ )
    {
        [hexString appendFormat:@"%02x", chars[i]];
    }
    free(chars);
	
    return hexString;
}

- (NSString *) fromHex
{
	return [NSString stringFromHex:self];
}

- (NSString *) toHex
{
	return [NSString stringToHex:self];
}

@end
