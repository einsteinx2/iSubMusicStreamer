//
//  NSString+MD5.h
//  EX2Kit
//
//  Created by Ben Baron on 4/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MD5)

+ (NSString *)md5:(NSString *)str;
- (NSString *)md5;

@end
