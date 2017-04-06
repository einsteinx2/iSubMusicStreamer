//
//  UIColor+ColorWithHex.m
//  ColorWithHex
//
//  Created by Angelo Villegas on 3/24/11.
//  Copyright (c) 2011 Studio Villegas.
//	http://www.studiovillegas.com/
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "UIColor+ColorWithHex.h"

@implementation UIColor (ColorWithHex)

#pragma mark - Category Methods
// Direct Conversion to hexadecimal (Automatic)
+ (UIColor *)colorWithHex:(UInt32)hexadecimal
{
	CGFloat red, green, blue;
	
	// Bit shift right the hexadecimal's first 2 values
	red = (hexadecimal >> 16) & 0xFF;
	// Bit shift right the hexadecimal's 2 middle values
	green = (hexadecimal >> 8) & 0xFF;
	// Bit shift right the hexadecimal's last 2 values
	blue = hexadecimal & 0xFF;
	
    return [UIColor colorWithRed: red / 255.0f green: green / 255.0f blue: blue / 255.0f alpha: 1.0f];
}

+ (UIColor *)colorWithHexString:(NSString *)hexadecimal
{
    if (!hexadecimal)
        return nil;
    
	// Convert Objective-C NSString to C string
	const char *cString = [hexadecimal cStringUsingEncoding: NSASCIIStringEncoding];
	int hex;
	
	/*
	 If the string contains hash tag (#)
	 If yes then remove hash tag and convert the C string
	 to a base-16 int
	 */
	if (cString[0] == '#')
	{
		hex = (int)strtol(cString + 1, NULL, 16);
	}
	else
	{
		hex = (int)strtol(cString, NULL, 16);
	}
	
	return [UIColor colorWithHex: hex];
}

+ (UIColor *)colorWithAlphaHex:(UInt32)hexadecimal
{
	CGFloat red, green, blue, alpha;
	
	// Bit shift right the hexadecimal's first 2 values for alpha
	alpha = (hexadecimal >> 24) & 0xFF;
	red = (hexadecimal >> 16) & 0xFF;
	green = (hexadecimal >> 8) & 0xFF;
	blue = hexadecimal & 0xFF;
	
    return [UIColor colorWithRed: red / 255.0f green: green / 255.0f blue: blue / 255.0f alpha: alpha / 255.0f];
}

+ (UIColor *)colorWithAlphaHexString:(NSString *)hexadecimal
{
    if (!hexadecimal)
        return nil;
    
	const char *cString = [hexadecimal cStringUsingEncoding: NSASCIIStringEncoding];
	int hex;
	
	if (cString[0] == '#')
	{
		hex = (int)strtol(cString + 1, NULL, 16);
	}
	else
	{
		hex = (int)strtol(cString, NULL, 16);
	}
	
	return [UIColor colorWithAlphaHex: hex];
}

+ (NSString *)hexStringFromColor: (UIColor *)color
{
    if (!color)
        return nil;
    
	// Get the color components of the color
	const NSUInteger totalComponents = CGColorGetNumberOfComponents([color CGColor]);
	const CGFloat *components = CGColorGetComponents([color CGColor]);
	NSString *hexadecimal;
	
	// Some cases, totalComponents will have only 2 components such as
	// black, white, gray, etc..
	switch (totalComponents)
	{
		// Multiply it by 255 and display the result using an uppercase hexadecimal specifier (%X) with a character length of 2
		case 4 :
			hexadecimal = [NSString stringWithFormat: @"#%02X%02X%02X", (int)(255 * components[0]), (int)(255 * components[1]), (int)(255 * components[2])];
			break;
			
		case 2 :
			hexadecimal = [NSString stringWithFormat: @"#%02X%02X%02X", (int)(255 * components[0]), (int)(255 * components[0]), (int)(255 * components[0])];
			break;
		
		default:
			break;
	}
	
	return hexadecimal;
}

+ (UIColor *)randomColor
{
	static BOOL generated = NO;
	
	// If the randomColor hasn't been generated yet,
	// reset the time to generate another sequence
	if (!generated)
	{
		generated = YES;
		srandom((uint)time(NULL));
	}
	
	// Generate a random number and divide it using the
	// maximum possible number random() can be generated
	CGFloat red = (CGFloat)random() / (CGFloat)RAND_MAX;
	CGFloat green = (CGFloat)random() / (CGFloat)RAND_MAX;
	CGFloat blue = (CGFloat)random() / (CGFloat)RAND_MAX;
	
	return [UIColor colorWithRed: red green: green blue: blue alpha: 1.0f];
}

#pragma mark -
// Converting using Hex to RGB formula (Manual)
+ (UIColor *)colorWithHexa:(NSString *)hexadecimal
{
	// Make sure that the hexadecimal value has an uppercase letters
	hexadecimal = [hexadecimal uppercaseString];
	NSInteger a;
	
	/*
	 If hexadecimal has a hash tag (#), remove it.
	 This purpose is solely for copy-pasting the whole hexadecimal
	 value that mostly consist of a hash-tag + the 6 characters
	 (e.i. #000000). Making sure that our little piece of software
	 will still accept the format.
	 */
	if ([[hexadecimal substringWithRange: NSMakeRange(0, 1)] isEqualToString: @"#"])
	{
		a = 1;
	}
	else
	{
		a = 0;
	}
	
	/*
	 In hexadecimal, all numbers beyond 9 will be converted to single
	 character (Base16 digits should be converted beyond the digit 9)
	 Conversion:
	 10 = A	11 = B	12 = C	13 = D	14 = E	15 = F
	 */
    NSDictionary *hexConstants = @{@"A":@"10", @"B":@"11", @"C":@"12", @"D":@"13", @"E":@"14", @"F":@"15"};
	NSMutableArray *hexArray = [[NSMutableArray alloc] init];
	NSMutableArray *hexConverted = [[NSMutableArray alloc] init];
	
	// Separate all the characters
	for (NSInteger x = a; x < [hexadecimal length]; x++)
	{
		[hexArray insertObject: [hexadecimal substringWithRange: NSMakeRange(x, 1)]	atIndex: x - 1];
	}
	
	// Convert the characters to their respective Base16 format
	for (NSString *hexa in hexArray)
	{
		if ([hexConstants valueForKey: hexa])
		{
			[hexConverted addObject: [hexConstants valueForKey: hexa]];
		}
		else
		{
			[hexConverted addObject: hexa];
		}
	}
	
	CGFloat red = 0.0;
	CGFloat green = 0.0;
	CGFloat blue = 0.0;
	
	/*
	 Calculation of Hex to RGB :	# x y x' y' x" y"
	 x  * 16 = (x ) + y  = R
	 x' * 16 = (x') + y' = G
	 x" * 16 = (x") + y" = B
	 */
	for (NSInteger x = 0; x < [hexConverted count]; x++)
	{
		switch (x)
		{
			case 0 :
			{
				const int value = [[hexConverted objectAtIndex: x] integerValue];
				red = value * 16 + [[hexConverted objectAtIndex: x + 1] integerValue];
				break;
			}
			case 2 :
			{
				const int value = [[hexConverted objectAtIndex: x] integerValue];
				green = value * 16 + [[hexConverted objectAtIndex: x + 1] integerValue];
				break;
			}
			case 4 :
			{
				const int value = [[hexConverted objectAtIndex: x] integerValue];
				blue = value * 16 + [[hexConverted objectAtIndex: x + 1] integerValue];
				break;
			}
			default:
				break;
		}
	}
	
	return [UIColor colorWithRed: red / 255.0f green: green / 255.0f blue: blue / 255.0f alpha: 1.0f];
}

@end
