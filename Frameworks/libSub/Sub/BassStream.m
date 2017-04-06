//
//  BassUserInfo.m
//  Anghami
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassStream.h"
#import "ISMSSong.h"

@implementation BassStream

- (id)init
{
	if ((self = [super init]))
	{
		_neededSize = ULLONG_MAX;
	}
	return self;
}

- (void)dealloc
{
    [_fileHandle closeFile];
}

- (unsigned long long)localFileSize
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.writePath error:NULL] fileSize];
}

- (NSUInteger)hash
{
	return _stream;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
	
    // Since we only use isEqual to remove BassStream objects from arrays
    // we want to make sure we match only on memory address
    /*if (!other || ![other isKindOfClass:[self class]])
     return NO;
     
     return [self isEqualToStream:other];*/
    return NO;
}

/*- (BOOL)isEqualToStream:(BassStream *)otherStream
{
    if (self == otherStream)
        return YES;
	
	if (!self.song || !otherStream.song)
		return NO;
	
	if ([self.song isEqualToSong:otherStream.song] && self.stream == otherStream.stream)
		return YES;
	
	return NO;
}*/

@end
