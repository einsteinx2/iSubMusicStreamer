//
//  EX2RingBuffer.h
//  EX2Kit
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EX2RingBuffer : NSObject

@property NSInteger maximumLength;

@property (strong) NSData *buffer;
@property (nonatomic) NSInteger readPosition;
@property (nonatomic) NSInteger writePosition;
@property (nonatomic, readonly) NSInteger totalLength;
@property (nonatomic, readonly) NSInteger freeSpaceLength;
@property (nonatomic, readonly) NSInteger filledSpaceLength;
@property NSInteger totalBytesDrained;

- (instancetype)initWithBufferLength:(NSInteger)bytes;
+ (instancetype)ringBufferWithLength:(NSInteger)bytes;

- (BOOL)fillWithBytes:(const void *)byteBuffer length:(NSInteger)bufferLength;
- (BOOL)fillWithData:(NSData *)data;

- (NSInteger)drainBytes:(void *)byteBuffer length:(NSInteger)bufferLength;
- (NSData *)drainData:(NSInteger)length;

- (BOOL)hasSpace:(NSInteger)length;

- (void)reset;

@end
