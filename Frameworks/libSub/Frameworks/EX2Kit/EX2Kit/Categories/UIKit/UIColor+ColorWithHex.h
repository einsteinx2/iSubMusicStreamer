//
//  UIColor+ColorWithHex.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIColor (ColorWithHex)
// Convert hexadecimal value to RGB
+ (UIColor *)colorWithHex:(UInt32)hexadecimal;
+ (UIColor *)colorWithHexString:(NSString *)hexadecimal;

// Convert hexadecimal value to RGB
// format:
//	0x = Hexadecimal specifier (# for strings)
//	ff = alpha, ff = red, ff = green, ff = blue
+ (UIColor *)colorWithAlphaHex:(UInt32)hexadecimal;
+ (UIColor *)colorWithAlphaHexString:(NSString *)hexadecimal;

// Return the hexadecimal value of the RGB color specified.
+ (NSString *)hexStringFromColor: (UIColor *)color;

// Generates a color randomly
+ (UIColor *)randomColor;

// ObjC (manual hex conversion to RGB)
+ (UIColor *)colorWithHexa:(NSString *)hexadecimal;

@end