//
//  EX2RingBuffer.m
//  EX2Kit
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "EX2RingBuffer.h"

@interface EX2RingBuffer ()
{
	void *_bufferBackingStore;
    long long _totalBytesDrained;
}
@end

@implementation EX2RingBuffer

- (long long)totalBytesDrained
{
    return _totalBytesDrained;
}

- (void)setTotalBytesDrained:(long long)totalBytesDrained
{
    _totalBytesDrained = totalBytesDrained;
}

- (id)initWithBufferLength:(NSUInteger)bytes
{
	if ((self = [super init]))
	{
        _maximumLength = bytes; // default to no expansion
		_bufferBackingStore = malloc(bytes);
		_buffer = [NSData dataWithBytesNoCopy:_bufferBackingStore length:bytes freeWhenDone:YES];
		[self reset];
	}
	return self;
}

+ (id)ringBufferWithLength:(NSUInteger)bytes
{
	return [[EX2RingBuffer alloc] initWithBufferLength:bytes];
}

- (void)reset
{
    @synchronized(self)
	{
        self.readPosition = 0;
        self.writePosition = 0;
        _totalBytesDrained = 0;
    }
}

- (NSUInteger)totalLength
{
	return self.buffer.length;
}

- (NSUInteger)freeSpaceLength
{
	@synchronized(self)
	{
		return self.totalLength - self.filledSpaceLength;
	}
}

- (NSUInteger)filledSpaceLength
{
	@synchronized(self)
	{
		if (self.readPosition <= self.writePosition)
		{
			return self.writePosition - self.readPosition;
		}
		else
		{
			// The write position has looped around
			return self.totalLength - self.readPosition + self.writePosition;
		}
	}
}

- (void)advanceWritePosition:(NSUInteger)writeLength
{
	@synchronized(self)
	{
		//NSUInteger oldWritePosition = self.writePosition;
		
		self.writePosition += writeLength;
		if (self.writePosition >= self.totalLength)
		{
			self.writePosition = self.writePosition - self.totalLength;
		}
		
		//DLog(@"writeLength: %i old writePosition: %i  new writePosition: %i", writeLength, oldWritePosition, self.writePosition);
	}
}

- (void)advanceReadPosition:(NSUInteger)readLength
{
	@synchronized(self)
	{
		//NSUInteger oldReadPosition = self.readPosition;
		
		self.readPosition += readLength;
		if (self.readPosition >= self.totalLength)
		{
			self.readPosition = self.readPosition - self.totalLength;
		}
		//DLog(@"readLength: %i old readPosition:%i  new readPosition: %i", readLength, oldReadPosition, self.readPosition);
	}
}

- (BOOL)fillWithBytes:(const void *)byteBuffer length:(NSUInteger)bufferLength
{	
	@synchronized(self)
	{
		// Make sure there is space
		if (self.freeSpaceLength > bufferLength)
		{
			NSUInteger bytesUntilEnd = self.totalLength - self.writePosition;
			if (bufferLength > bytesUntilEnd)
			{
				// Split it between the end and beginning
				memcpy(_bufferBackingStore + self.writePosition, byteBuffer, bytesUntilEnd);
				memcpy(_bufferBackingStore, byteBuffer + bytesUntilEnd, bufferLength - bytesUntilEnd);
			}
			else
			{
				// Just copy in the bytes
				memcpy(_bufferBackingStore + self.writePosition, byteBuffer, bufferLength);
			}
			
			//DLog(@"filled %i bytes, free: %i, filled: %i, writPos: %i, readPos: %i", bufferLength, self.freeSpaceLength, self.filledSpaceLength, self.writePosition, self.readPosition);
			
			[self advanceWritePosition:bufferLength];
            
            //DLog(@"ring buffer, filled space: %i", self.filledSpaceLength);
			
			return YES;
		}
        else if (self.totalLength < self.maximumLength)
        {            
            // Expand the buffer and try to fill it again
            if ([self expand])
            {
                return [self fillWithBytes:byteBuffer length:bufferLength];
            }
        }
        
		return NO;
	}
}

- (BOOL)fillWithData:(NSData *)data
{
	return [self fillWithBytes:data.bytes length:data.length];
}

- (NSUInteger)drainBytes:(void *)byteBuffer length:(NSUInteger)bufferLength
{
	@synchronized(self)
	{
		bufferLength = self.filledSpaceLength >= bufferLength ? bufferLength : self.filledSpaceLength;
		
		if (bufferLength > 0) 
		{
			NSUInteger bytesUntilEnd = self.totalLength - self.readPosition;
			if (bufferLength > bytesUntilEnd)
			{
				// Split it between the end and beginning
				memcpy(byteBuffer, _bufferBackingStore + self.readPosition, bytesUntilEnd);
				memcpy(byteBuffer + bytesUntilEnd, _bufferBackingStore, bufferLength - bytesUntilEnd);
			}
			else
			{
				// Just copy in the bytes
				memcpy(byteBuffer, _bufferBackingStore + self.readPosition, bufferLength);
			}
            
            // Add the number of bytes to totalDrainedBytes
            _totalBytesDrained += bufferLength;
			
			//DLog(@"read %i bytes, free: %i, filled: %i, writPos: %i, readPos: %i", bufferLength, self.freeSpaceLength, self.filledSpaceLength, self.writePosition, self.readPosition);
			
			[self advanceReadPosition:bufferLength];		
		}
		return bufferLength;
	}
}

- (NSData *)drainData:(NSUInteger)readLength
{
	void *byteBuffer = malloc(sizeof(char) * readLength);
	readLength = [self drainBytes:byteBuffer length:readLength];
	if (readLength > 0)
	{
		return [NSData dataWithBytesNoCopy:byteBuffer length:readLength freeWhenDone:YES];
	}
	else
	{
		free(byteBuffer);
		return nil;
	}
}

- (BOOL)hasSpace:(NSUInteger)length
{
	return self.freeSpaceLength >= length;
}

- (BOOL)expand
{
    // Expand by 25%
    return [self expand:(NSUInteger)((double)self.totalLength * 1.25)];
}

- (BOOL)expand:(NSUInteger)size
{
    @synchronized(self)
	{
        if (size <= self.totalLength)
            return NO;
                
        // First try to expand the backing buffer
        void *tempBuffer = malloc(sizeof(char) * size);
        if (tempBuffer == NULL)
        {
            // malloc failed
            return NO;
        }
        else
        {
            // Drain all the bytes into the new buffer
            NSUInteger filledSize = self.filledSpaceLength;
            [self drainBytes:tempBuffer length:filledSize];
            
            // Adjust the read and write positions
            self.readPosition = 0;
            self.writePosition = filledSize;
            
            // Swap out the buffers
            _buffer = nil;
            _bufferBackingStore = tempBuffer;
            _buffer = [NSData dataWithBytesNoCopy:_bufferBackingStore length:size freeWhenDone:YES];
            
            return YES;
        }
    }
}

@end
