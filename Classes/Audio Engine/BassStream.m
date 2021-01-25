//
//  BassUserInfo.m
//  iSub
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassStream.h"
#import "Swift.h"
#import "Defines.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

LOG_LEVEL_ISUB_DEFAULT

@implementation BassStream

- (instancetype)init
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

- (NSInteger)localFileSize
{
    NSError *error = nil;
    NSDictionary<NSURLResourceKey, id> *resourceValues = [[NSURL fileURLWithPath:self.writePath] resourceValuesForKeys:@[NSURLTotalFileAllocatedSizeKey] error:&error];
    if (error) {
        DDLogError(@"[BassStream] error reading local file size: %@", error.localizedDescription);
        return 0;
    }
    
    return [resourceValues[NSURLTotalFileAllocatedSizeKey] integerValue];    
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
	
	if ([self.song isEqual:otherStream.song] && self.stream == otherStream.stream)
		return YES;
	
	return NO;
}*/

@end
