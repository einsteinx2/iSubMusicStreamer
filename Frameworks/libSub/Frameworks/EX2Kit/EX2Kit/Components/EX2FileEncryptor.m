//
//  EX2FileEncryptor.m
//  EX2Kit
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2FileEncryptor.h"
#import "EX2FileDecryptor.h"
//#import "RNCryptor.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "EX2RingBuffer.h"
#import "DDLog.h"

@interface EX2FileEncryptor()
{
	NSString *_key;
}
@property (nonatomic, strong, readonly) EX2RingBuffer *encryptionBuffer;
@property (nonatomic, strong, readonly) NSFileHandle *fileHandle;
@end

@implementation EX2FileEncryptor

static const int ddLogLevel = LOG_LEVEL_INFO;

#define DEFAULT_CHUNK_SIZE 4096

- (id)init
{
	return [self initWithChunkSize:DEFAULT_CHUNK_SIZE];
}

- (id)initWithChunkSize:(NSUInteger)theChunkSize
{
	if ((self = [super init]))
	{
		_chunkSize = theChunkSize;
		_encryptionBuffer = [[EX2RingBuffer alloc] initWithBufferLength:_chunkSize * 10];
	}
	return self;
}

- (id)initWithPath:(NSString *)aPath chunkSize:(NSUInteger)theChunkSize key:(NSString *)theKey
{
	if ((self = [self initWithChunkSize:theChunkSize]))
	{
		_key = [theKey copy];
		_path = [aPath copy];
		_fileHandle = [NSFileHandle fileHandleForWritingAtPath:_path];
		if (_fileHandle)
		{
			[_fileHandle seekToEndOfFile];
		}
		else
		{
			// No file exists, so create one
			[[NSFileManager defaultManager] createFileAtPath:_path contents:[NSData data] attributes:nil];
			_fileHandle = [NSFileHandle fileHandleForWritingAtPath:_path];
		}
        
        [EX2FileDecryptor registerOpenFilePath:_path];
	}
	return self;
}

- (void)dealloc
{
    // Make sure the file handle is closed and recorded
    [self closeFile];
}

- (NSUInteger)writeBytes:(const void *)buffer length:(NSUInteger)length
{
	if (!self.fileHandle)
		return 0;
	
	[self.encryptionBuffer fillWithBytes:buffer length:length];
	
	NSUInteger bytesWritten = 0;
	while (self.encryptionBuffer.filledSpaceLength >= self.chunkSize)
	{
		NSData *data = [self.encryptionBuffer drainData:self.chunkSize];
		NSError *encryptionError;
		NSTimeInterval start = [[NSDate date] timeIntervalSince1970];	
		//NSData *encrypted = [[RNCryptor AES256Cryptor] encryptData:data password:_key error:&encryptionError];
        NSData *encrypted = [RNEncryptor encryptData:data withSettings:kRNCryptorAES256Settings password:_key error:&encryptionError];
		DDLogVerbose(@"[EX2FileEncryptor] total time: %f", [[NSDate date] timeIntervalSince1970] - start);

		//DLog(@"data size: %u  encrypted size: %u", data.length, encrypted.length);
		if (encryptionError)
		{
			DDLogError(@"[EX2FileEncryptor] Encryptor: ERROR THERE WAS AN ERROR ENCRYPTING THIS CHUNK: %@", encryptionError);
			return bytesWritten;
		}
		else
		{
			// Save the data to the file
			@try
			{
				[self.fileHandle writeData:encrypted];
                [self.fileHandle synchronizeFile];
				bytesWritten += self.chunkSize;
			}
			@catch (NSException *exception) 
			{
				DDLogError(@"[EX2FileEncryptor] Encryptor: Failed to write to file");
				@throw(exception);
			}
		}
	}
	
	return bytesWritten;
}

- (NSUInteger)writeData:(NSData *)data
{
	return [self writeBytes:data.bytes length:data.length];
}

- (void)clearBuffer
{
	DDLogInfo(@"[EX2FileEncryptor] Encryptor: clearing the buffer");
	[self.encryptionBuffer reset];
}

- (BOOL)closeFile
{
    if (self.fileHandle)
    {
        DDLogInfo(@"[EX2FileEncryptor] Encryptor: closing the file");
        while (self.encryptionBuffer.filledSpaceLength > 0)
        {
            DDLogInfo(@"[EX2FileEncryptor] Encryptor: writing the remaining bytes");
            NSUInteger length = self.encryptionBuffer.filledSpaceLength >= 4096 ? 4096 : self.encryptionBuffer.filledSpaceLength;
            NSData *data = [self.encryptionBuffer drainData:length];
            
            NSError *encryptionError;
            //NSData *encrypted = [[RNCryptor AES256Cryptor] encryptData:data password:_key error:&encryptionError];
            NSData *encrypted = [RNEncryptor encryptData:data withSettings:kRNCryptorAES256Settings password:_key error:&encryptionError];
            //DLog(@"data size: %u  encrypted size: %u", data.length, encrypted.length);
            
            NSData *decrypted = [RNDecryptor decryptData:encrypted withPassword:_key error:nil];
            NSLog(@"decrypted length: %lu", (unsigned long)decrypted.length);
            if (encryptionError)
            {
                DDLogError(@"[EX2FileEncryptor] ERROR THERE WAS AN ERROR ENCRYPTING THIS CHUNK: %@", encryptionError);
                //return NO;
            }
            else
            {
                // Save the data to the file
                @try
                {
                    [self.fileHandle writeData:encrypted];
                }
                @catch (NSException *exception) 
                {
                    DDLogError(@"[EX2FileEncryptor] Encryptor: ERROR writing remaining bytes");
                }
            }
        }
        
        @try
        {
            [self.fileHandle synchronizeFile];
            [self.fileHandle closeFile];
        }
        @catch (NSException *exception)
        {
            DDLogError(@"[EX2FileEncryptor] Exception synchronizing and closing file handle: %@", exception);
        }
        _fileHandle = nil;
        
        [EX2FileDecryptor unregisterOpenFilePath:self.path];
        
        return YES;
    }
	
    return NO;
}

- (NSUInteger)encryptedChunkSize
{
	NSUInteger aesPaddedSize = ((self.chunkSize / 16) + 1) * 16;
	NSUInteger totalPaddedSize = aesPaddedSize + 66; // Add the RNCryptor padding
	return totalPaddedSize;
}

- (unsigned long long)encryptedFileSizeOnDisk
{
	// Just get the size from disk
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil] fileSize];
}

- (unsigned long long)decryptedFileSizeOnDisk
{
	// Find the encrypted size
	unsigned long long encryptedSize = self.encryptedFileSizeOnDisk;
	
	// Find padding size
	unsigned long long chunkPadding = self.encryptedChunkSize - self.chunkSize;
	unsigned long long numberOfEncryptedChunks = (encryptedSize / self.encryptedChunkSize);
	unsigned long long filePadding = numberOfEncryptedChunks * chunkPadding;
	
    // Calculate padding remainder
    int remainder = encryptedSize % self.encryptedChunkSize;
    if (remainder > 0)
    {
        // There is a partial chunk, so just assume full padding size (sometimes it can be a bit under for some reason, don't know why yet)
        filePadding += chunkPadding;
    }
    
	// Calculate the decrypted size
	unsigned long long decryptedSize = encryptedSize - filePadding;
	
	return decryptedSize;
}

- (NSUInteger)bytesInBuffer
{
	return self.encryptionBuffer.filledSpaceLength;
}

@end
