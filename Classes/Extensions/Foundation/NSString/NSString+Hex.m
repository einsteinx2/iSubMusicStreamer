//
//  NSString+Hex.m
//  EX2Kit
//
//  Created by Ben Baron on 10/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSString+Hex.h"

@implementation NSString (Hex)

+ (NSString *) stringFromHex:(NSString *)str  {
	NSMutableData *stringData = [[NSMutableData alloc] init];
	unsigned char wholeByte;
	char byteChars[3] = {'\0','\0','\0'};
	for (int i = 0; i < str.length / 2; i++) {
        byteChars[0] = [str characterAtIndex:i * 2];
        byteChars[1] = [str characterAtIndex:(i * 2) + 1];
        wholeByte = strtol(byteChars, NULL, 16);
		[stringData appendBytes:&wholeByte length:1];
	}
	
	return [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
}

+ (NSString *)stringToHex:(NSString *)str {
    NSUInteger len = [str length];
    unichar *chars = malloc(len * sizeof(unichar));
    [str getCharacters:chars];
	
    NSMutableString *hexString = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < len; i++ ) {
        [hexString appendFormat:@"%02x", chars[i]];
    }
    free(chars);
    return hexString;
}

- (NSString *) fromHex {
	return [NSString stringFromHex:self];
}

- (NSString *) toHex {
	return [NSString stringToHex:self];
}

@end
