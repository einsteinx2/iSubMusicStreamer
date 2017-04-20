//
//  NSString-hex.h
//  EX2Kit
//
//  Created by Ben Baron on 10/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface NSString (hex) 

+ (NSString *) stringFromHex:(NSString *)str;
+ (NSString *) stringToHex:(NSString *)str;

- (NSString *) fromHex;
- (NSString *) toHex;

@end
