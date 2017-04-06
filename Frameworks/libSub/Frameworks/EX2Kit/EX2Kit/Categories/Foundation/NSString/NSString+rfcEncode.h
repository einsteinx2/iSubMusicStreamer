//
//  NSString-rfcEncode.h
//  EX2Kit
//
//  Created by Ben Baron on 12/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//




@interface NSString (RFC3875)

- (NSString *)stringByAddingRFC3875PercentEscapesUsingEncoding:(NSStringEncoding)encoding;

@end
