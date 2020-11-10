//
//  NSFileHandle+Hash.m
//  EX2Kit
//
//  Created by Benjamin Baron on 3/29/13.
//
//

#import "NSFileHandle+Hash.h"
#import "DDLog.h"
#import "EX2Macros.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSFileHandle (Hash)

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define READ_CHUNK_SIZE BytesFromKB(16)

- (NSString *)sha1
{    
    @try
    {
        // Seek to the beginning
        [self seekToFileOffset:0];
        
        // Create and initialize the context
        CC_SHA1_CTX context;
        CC_SHA1_Init(&context);
        
        // Loop through the data, adding it to the rolling hash
        while (YES)
        {
            NSData *data = [self readDataOfLength:READ_CHUNK_SIZE];
            if (data.length == 0)
                break;
            
            CC_SHA1_Update(&context, data.bytes, (CC_LONG)data.length);
        }
        
        // Compute the final digest
        uint8_t digest[CC_SHA1_DIGEST_LENGTH];
        CC_SHA1_Final(digest, &context);
        
        // Convert the digest to a hex string for printing
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
        for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        {
            [output appendFormat:@"%02x", digest[i]];
        }
        return output;
    }
    @catch (NSException *exception)
    {
        DDLogError(@"[NSFileHandle+HashAndChecksum] Failed to generate SHA1 hash with exception %@", exception);
        return nil;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (NSString *)md5
{
    @try
    {
        // Seek to the beginning
        [self seekToFileOffset:0];
        if (self.availableData == 0)
            return nil;
        
        // Create and initialize the context
        CC_MD5_CTX context;
        CC_MD5_Init(&context);
        
        // Loop through the data, adding it to the rolling hash
        while (YES)
        {
            NSData *data = [self readDataOfLength:READ_CHUNK_SIZE];
            if (data.length == 0)
                break;
            
            CC_MD5_Update(&context, data.bytes, (CC_LONG)data.length);
        }
        
        // Compute the final digest
        uint8_t digest[CC_SHA1_DIGEST_LENGTH];
        CC_MD5_Final(digest, &context);
        
        // Convert the digest to a hex string for printing
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
        for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        {
            [output appendFormat:@"%02x", digest[i]];
        }
        return output;
    }
    @catch (NSException *exception)
    {
        DDLogError(@"[NSFileHandle+HashAndChecksum] Failed to generate MD5 hash with exception %@", exception);
        return nil;
    }
}
#pragma clang diagnostic pop

- (NSString *)crc32
{
    return nil;
}

- (NSString *)adler32
{
    return nil;
}

@end
