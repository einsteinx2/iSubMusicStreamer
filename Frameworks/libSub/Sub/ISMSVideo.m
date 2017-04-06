//
//  Video.m
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSVideo.h"

@implementation ISMSVideo

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.title];
}

- (NSUInteger)hash
{
	return self.itemId.hash;
}

- (BOOL)isEqualToVideo:(ISMSVideo *)otherVideo
{
    if (self == otherVideo)
        return YES;
	
	if (!self.itemId || !otherVideo.itemId)
		return NO;
	
	return [self.itemId isEqualToString:otherVideo.itemId];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToVideo:other];
}

@end
