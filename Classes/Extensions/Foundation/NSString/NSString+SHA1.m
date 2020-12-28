//
//  NSString+SHA1.m
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "NSString+SHA1.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (SHA1)

+ (NSString *)sha1:(NSString *)string {
    const char *cString = string.UTF8String;
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cString, (CC_LONG)strlen(cString), result);
    return [NSString  stringWithFormat:
        @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        result[0], result[1], result[2], result[3], result[4],
        result[5], result[6], result[7], result[8], result[9],
        result[10], result[11], result[12], result[13], result[14],
        result[15], result[16], result[17], result[18], result[19]
     ];
}

- (NSString *)sha1 {
    return [self.class sha1:self];
}

@end
