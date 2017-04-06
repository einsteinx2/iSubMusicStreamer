//
//  NSString-rfcEncode.m
//  EX2Kit
//
//  Created by Ben Baron on 12/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NSString+rfcEncode.h"

// TODO: Fix __bridges

@implementation NSString (RFC3875)
- (NSString *)stringByAddingRFC3875PercentEscapesUsingEncoding:(NSStringEncoding)encoding 
{
	/*CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
	NSString *urlEscaped = [self stringByAddingPercentEscapesUsingEncoding:encoding];
	NSString *rfcEscaped = (NSString *)CFURLCreateStringByAddingPercentEscapes(
																			   NULL, 
																			   (CFStringRef)urlEscaped,
																			   NULL, 
																			   (CFStringRef)@";/?:@&=$+{}<>,",
																			   cfEncoding);
	return [rfcEscaped autorelease];*/
	
	CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
	// NSString *urlEscaped = [self stringByAddingPercentEscapesUsingEncoding:encoding];
	NSString *rfcEscaped = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(
																			   NULL, 
																			   (__bridge CFStringRef)self,
																			   NULL, 
																			   (__bridge CFStringRef)@";/?:@&=$+{}<>,",
																			   cfEncoding);
	return rfcEscaped;
}

@end
