//
//  EX2FileDecryptor.m
//  EX2Kit
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2FileDecryptor.h"
#import "RNCryptorOld.h"
#import "RNDecryptor.h"
#import "EX2RingBuffer.h"
#import "DDLog.h"

// Keyed on file path, value is number of references
static __strong NSMutableDictionary *_activeFilePaths;

@interface EX2FileDecryptor()
{
	NSString *_key;
    NSArray *_alternateKeys;
}
@property (nonatomic, strong) EX2RingBuffer *tempDecryptBuffer;
@property (nonatomic, strong) EX2RingBuffer *decryptedBuffer;
@property (nonatomic) NSUInteger seekOffset;
@property (nonatomic, strong, readonly) NSFileHandle *fileHandle;
@property (nonatomic) BOOL useOldDecryptor;
@end

@implementation EX2FileDecryptor

#define DEFAULT_DECR_CHUNK_SIZE 4096

static const int ddLogLevel = LOG_LEVEL_INFO;

+ (NSDictionary *)openFilePaths
{
    return [NSDictionary dictionaryWithDictionary:_activeFilePaths];
}

+ (void)registerOpenFilePath:(NSString *)path
{
    if (!path)
        return;
    
    @synchronized(self)
    {
        // Make sure the dictionary exists
        if (!_activeFilePaths)
        {
            _activeFilePaths = [NSMutableDictionary dictionaryWithCapacity:10];
        }
        
        // Note that if the entry doesn't exist, this still works because [_activeFilePaths[path] integerValue] evaluates to 0
        // when _activeFilePaths[path] is nil
        NSInteger adjustedValue = [_activeFilePaths[path] integerValue] + 1;
        
        NSLog(@"EX2FileDecryptor: incremented \"%@\" (%li)", path, (long)adjustedValue);
        _activeFilePaths[path] = @(adjustedValue);
        
        DLog(@"_activeFilePaths: %@", _activeFilePaths);
    }
}

+ (void)unregisterOpenFilePath:(NSString *)path
{
    if (!path)
        return;
    
    @synchronized(self)
    {        
        NSInteger adjustedValue = [_activeFilePaths[path] integerValue] - 1;
        if (adjustedValue <= 0)
        {
            // If decrementing the value will bring it to 0, remove the entry
            [_activeFilePaths removeObjectForKey:path];
            NSLog(@"EX2FileDecryptor: removing \"%@\" (%li)", path, (long)adjustedValue);
        }
        else
        {
            _activeFilePaths[path] = @(adjustedValue);
            NSLog(@"EX2FileDecryptor: decremented \"%@\" (%li)", path, (long)adjustedValue);
        }
        
        DLog(@"_activeFilePaths: %@", _activeFilePaths);
    }
}

+ (BOOL)isFilePathInUse:(NSString *)path
{
    if (!path)
        return NO;
    
    @synchronized(self)
    {
        // If the dictionary contains this path, then the ref count must be greater than 0
        return [_activeFilePaths.allKeys containsObject:path];
    }
}

- (id)init
{
	return [self initWithChunkSize:DEFAULT_DECR_CHUNK_SIZE];
}

- (id)initWithChunkSize:(NSUInteger)theChunkSize
{
	if ((self = [super init]))
	{
		_chunkSize = theChunkSize;
        
		_tempDecryptBuffer = [[EX2RingBuffer alloc] initWithBufferLength:BytesFromKiB(75)];
        _tempDecryptBuffer.maximumLength = BytesFromKiB(500);
        
		_decryptedBuffer = [[EX2RingBuffer alloc] initWithBufferLength:BytesFromKiB(75)];
        _decryptedBuffer.maximumLength = BytesFromKiB(500);
	}
	return self;
}

- (id)initWithPath:(NSString *)aPath chunkSize:(NSUInteger)theChunkSize key:(NSString *)theKey alternateKeys:(NSArray *)alternateKeys
{
	if ((self = [self initWithChunkSize:theChunkSize]))
	{
		_key = [theKey copy];
		_path = [aPath copy];
		_fileHandle = [NSFileHandle fileHandleForReadingAtPath:aPath];
        _alternateKeys = [alternateKeys copy];
        
        [EX2FileDecryptor registerOpenFilePath:_path];
	}
	return self;
}

- (id)initWithPath:(NSString *)aPath chunkSize:(NSUInteger)theChunkSize key:(NSString *)theKey
{
    return [self initWithPath:aPath chunkSize:theChunkSize key:theKey alternateKeys:nil];
}

- (void)dealloc
{
    // Make sure the file handle is closed and recorded
    [self closeFile];
}

- (BOOL)seekToOffset:(NSUInteger)offset
{
	BOOL success = NO;
	
	NSUInteger padding = ((int)(offset / self.chunkSize) * self.encryptedChunkPadding); // Calculate the encryption padding
	NSUInteger mod = (offset + padding) % self.encryptedChunkSize;
	NSUInteger realOffset = (offset + padding) - mod; // only seek in increments of the encryption blocks
    
    // Check if this much of the file even exists
    if (self.encryptedFileSizeOnDisk >= realOffset + mod)
    {
        self.seekOffset = mod;
        
        DDLogVerbose(@"[EX2FileDecryptor] offset: %lu  padding: %lu  realOffset: %lu  mod: %lu:  for path: %@", (unsigned long)offset, (unsigned long)padding, (unsigned long)realOffset, (unsigned long)mod, self.path);
        
        @try 
        {
            [self.fileHandle seekToFileOffset:realOffset];
            success = YES;
        } 
        @catch (NSException *exception) 
        {
            DDLogError(@"[EX2FileDecryptor] exception seeking to offset %lu, %@ for path: %@", (unsigned long)offset, exception, self.path);
        }
        
        if (success)
        {
            [self.tempDecryptBuffer reset];
            [self.decryptedBuffer reset];
        }
    }
	
	return success;
}

- (NSUInteger)readBytes:(void *)buffer length:(NSUInteger)length
{
	if (self.decryptedBuffer.filledSpaceLength < length)
	{
		NSUInteger encryptedChunkSize = self.encryptedChunkSize;
		
		DDLogVerbose(@"[EX2FileDecryptor]   ");
		DDLogVerbose(@"[EX2FileDecryptor] asked to read length: %lu for path: %@", (unsigned long)length, self.path);
		// Round up the read to the next block
		//length = self.decryptedBuffer.filledSpaceLength - length;
		NSUInteger realLength = self.seekOffset + length;
		
		if (((self.chunkSize - self.seekOffset) + (length / self.chunkSize)) < length)
		{
			// We need to read an extra chunk
			realLength += self.encryptedChunkSize;
		}
		
		DDLogVerbose(@"[EX2FileDecryptor] seek offset %lu  realLength %lu for path: %@", (unsigned long)self.seekOffset, (unsigned long)realLength, self.path);
		NSUInteger mod = realLength % encryptedChunkSize;
		if (mod > self.chunkSize)
		{
			realLength += encryptedChunkSize;
			mod -= self.chunkSize;
		}
		
		DDLogVerbose(@"[EX2FileDecryptor] mod %lu for path: %@", (unsigned long)mod, self.path);
		//if (mod != 0)
		if (realLength % encryptedChunkSize != 0)
		{
			// pad to the next block
			//realLength += ENCR_CHUNK_SIZE - mod; 
			realLength = ((int)(realLength / encryptedChunkSize) * encryptedChunkSize) + encryptedChunkSize;
		}
		DDLogVerbose(@"[EX2FileDecryptor] reading length: %lu for path: %@", (unsigned long)realLength, self.path);
		
		DDLogVerbose(@"[EX2FileDecryptor] file offset: %llu for path: %@", self.fileHandle.offsetInFile, self.path);
		
		// We need to decrypt some more data
		[self.tempDecryptBuffer reset];
		NSData *readData;
		@try {
			readData = [self.fileHandle readDataOfLength:realLength];
		} @catch (NSException *exception) {
			readData = nil;
		}
		DDLogVerbose(@"[EX2FileDecryptor] read data length %lu for path: %@", (unsigned long)readData.length, self.path);
		
		if (readData)
		{
			DDLogVerbose(@"[EX2FileDecryptor] filling temp buffer with data for path: %@", self.path);
			[self.tempDecryptBuffer fillWithData:readData];
			DDLogVerbose(@"[EX2FileDecryptor] temp buffer filled size %lu for path: %@", (unsigned long)self.tempDecryptBuffer.filledSpaceLength, self.path);
		}
		
		while (self.tempDecryptBuffer.filledSpaceLength >= encryptedChunkSize)
		{
			DDLogVerbose(@"[EX2FileDecryptor] draining data for path: %@", self.path);
			NSData *data = [self.tempDecryptBuffer drainData:encryptedChunkSize];
			DDLogVerbose(@"[EX2FileDecryptor] data drained, filled size %lu for path: %@", (unsigned long)self.tempDecryptBuffer.filledSpaceLength, self.path);
            
            DDLogVerbose(@"[EX2FileDecryptor] decrypting data for path: %@", self.path);
			NSError *decryptionError;
            NSData *decrypted;
            if (!self.useOldDecryptor)
            {
                decrypted = [RNDecryptor decryptData:data withPassword:_key error:&decryptionError];
                DDLogVerbose(@"[EX2FileDecryptor] data size: %lu  decrypted size: %lu for path: %@", (unsigned long)data.length, (unsigned long)decrypted.length, self.path);
            }
            
            if (decryptionError && _alternateKeys)
			{
                if (decryptionError)
                {
                    _error = decryptionError;
                    DDLogError(@"[EX2FileDecryptor] There was an error decrypting this chunk using new decryptor, trying the alternate keys: %@ for path: %@", decryptionError, self.path);
                }
                
                decryptionError = nil;
                for (NSString *alternate in _alternateKeys)
                {
                    decrypted = [RNDecryptor decryptData:data withPassword:alternate error:&decryptionError];
                    DDLogVerbose(@"[EX2FileDecryptor] data size: %lu  decrypted size: %lu for path: %@", (unsigned long)data.length, (unsigned long)decrypted.length, self.path);
                    if (decryptionError)
                    {
                        DDLogError(@"[EX2FileDecryptor] There was an error decrypting this chunk using an alternate key: %@  for path: %@", decryptionError, self.path);
                    }
                    else
                    {
                        DDLogError(@"[EX2FileDecryptor] The alternate key was successful, storing that as the new key for path: %@", self.path);
                        _key = alternate;
                        _error = nil;
                        break;
                    }
                }
			}
            
			if (decryptionError || self.useOldDecryptor)
			{
                if (decryptionError)
                {
                    _error = decryptionError;
                    DDLogError(@"[EX2FileDecryptor] There was an error decrypting this chunk using new decryptor, trying old decryptor: %@ for path: %@", decryptionError, self.path);
                }
                
                decryptionError = nil;
                decrypted = [[RNCryptorOld AES256Cryptor] decryptData:data password:_key error:&decryptionError];
                DDLogVerbose(@"[EX2FileDecryptor] data size: %lu  decrypted size: %lu for path: %@", (unsigned long)data.length, (unsigned long)decrypted.length, self.path);
                if (decryptionError)
                {
                    DDLogError(@"[EX2FileDecryptor] There was an error decrypting this chunk using old decryptor, giving up: %@  for path: %@", decryptionError, self.path);
                }
                else
                {
                    self.useOldDecryptor = YES;
                    _error = nil;
                }
			}
            
			if (!decryptionError)
			{
				// Add the data to the decryption buffer
				if (self.seekOffset > 0)
				{
					DDLogVerbose(@"[EX2FileDecryptor] seek offset greater than 0 for path: %@", self.path);
					const void *tempBuff = decrypted.bytes;
					DDLogVerbose(@"[EX2FileDecryptor] filling decrypted buffer length %lu for path: %@", (unsigned long)(self.chunkSize - self.seekOffset), self.path);
					[self.decryptedBuffer fillWithBytes:tempBuff+self.seekOffset length:self.chunkSize-self.seekOffset];
					self.seekOffset = 0;
					DDLogVerbose(@"[EX2FileDecryptor] setting seekOffset to 0 for path: %@", self.path);
				}
				else
				{
					DDLogVerbose(@"[EX2FileDecryptor] filling decrypted buffer with data length %lu for path: %@", (unsigned long)decrypted.length, self.path);
					[self.decryptedBuffer fillWithData:decrypted];
					DDLogVerbose(@"[EX2FileDecryptor] filled decrypted buffer for path: %@", self.path);
				}
			}
		}
	}
	
	// See if there's enough data in the decrypted buffer
	NSUInteger bytesRead = self.decryptedBuffer.filledSpaceLength >= length ? length : self.decryptedBuffer.filledSpaceLength;
	if (bytesRead > 0)
	{
		DDLogVerbose(@"[EX2FileDecryptor] draining bytes into buffer length %lu for path: %@", (unsigned long)bytesRead, self.path);
		[self.decryptedBuffer drainBytes:buffer length:bytesRead];
		DDLogVerbose(@"[EX2FileDecryptor] bytes drained for path: %@", self.path);
	}
    else
    {
        DDLogVerbose(@"[EX2FileDecryptor] bytes read was 0 so not draining anything for path: %@", self.path);
    }

	return bytesRead;
}

- (NSData *)readData:(NSUInteger)length
{
	void *buffer = malloc(sizeof(char) * length);
	NSUInteger realLength = [self readBytes:buffer length:length];
	NSData *returnData = nil;
	if (realLength > 0)
	{
		returnData = [NSData dataWithBytesNoCopy:buffer length:realLength freeWhenDone:YES];
	}
	DDLogVerbose(@"[EX2FileDecryptor] read bytes length %lu for path: %@", (unsigned long)realLength, self.path);
	return returnData;
}

- (void)closeFile
{
    if (self.fileHandle)
    {
        DDLogInfo(@"[EX2FileDecryptor] closing file for path: %@", self.path);
        
        [self.tempDecryptBuffer reset];
        [self.decryptedBuffer reset];
        [self.fileHandle closeFile];
        _fileHandle = nil;
        
        [EX2FileDecryptor unregisterOpenFilePath:self.path];
    }	
}

- (NSUInteger)encryptedChunkPadding
{
	return self.encryptedChunkSize - self.chunkSize;
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

@end
