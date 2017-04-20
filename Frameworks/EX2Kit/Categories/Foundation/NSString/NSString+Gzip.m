//
//  NSString+Gzip.m
//  Anghami
//
//  Created by Ben Baron on 9/6/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSString+Gzip.h"

@implementation NSString (Gzip)

+ (NSString *)stringFromGzipData:(NSData *)data
{
    return [self stringFromGzipData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)stringFromGzipData:(NSData *)data encoding:(NSStringEncoding)encoding
{
    return [[NSString alloc] initWithData:[data gzipDecompress] encoding:encoding];
}

- (NSData *)gzipCompressWithEncoding:(NSStringEncoding)encoding
{
    return [[self dataUsingEncoding:encoding] gzipCompress];
}

- (NSData *)gzipCompress
{
    return [self gzipCompressWithEncoding:NSUTF8StringEncoding];
}

@end
