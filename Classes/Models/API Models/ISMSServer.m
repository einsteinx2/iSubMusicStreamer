//
//  Server.m
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSServer.h"

@implementation ISMSServer

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.url];
	[encoder encodeObject:self.username];
	[encoder encodeObject:self.password];
	[encoder encodeObject:self.type];
    [encoder encodeObject:self.lastQueryId];
    [encoder encodeObject:self.uuid];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_url = [[decoder decodeObject] copy];
		_username = [[decoder decodeObject] copy];
		_password = [[decoder decodeObject] copy];
		_type = [[decoder decodeObject] copy];
        _lastQueryId = [[decoder decodeObject] copy];
        _uuid = [[decoder decodeObject] copy];
	}
	
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@  type: %@", [super description], self.type];
}

@end
