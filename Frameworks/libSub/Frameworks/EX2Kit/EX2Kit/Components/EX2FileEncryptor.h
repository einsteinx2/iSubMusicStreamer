//
//  EX2FileEncryptor.h
//  EX2Kit
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EX2FileEncryptor : NSObject

@property (nonatomic, readonly) NSUInteger chunkSize;
@property (nonatomic, readonly) NSUInteger encryptedChunkSize;
@property (nonatomic, readonly) NSString *path;

@property (nonatomic, readonly) NSUInteger bytesInBuffer;

@property (nonatomic, readonly) unsigned long long encryptedFileSizeOnDisk;
@property (nonatomic, readonly) unsigned long long decryptedFileSizeOnDisk;

- (id)initWithPath:(NSString *)path chunkSize:(NSUInteger)chunkSize key:(NSString *)key;

- (NSUInteger)writeBytes:(const void *)buffer length:(NSUInteger)length;
- (NSUInteger)writeData:(NSData *)data;
- (BOOL)closeFile;
- (void)clearBuffer;

@end
