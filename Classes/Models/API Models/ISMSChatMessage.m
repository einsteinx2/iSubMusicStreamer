//
//  ChatMessage.m
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSChatMessage.h"
#import "RXMLElement.h"
#import "EX2Kit.h"

@implementation ISMSChatMessage

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		_timestamp = NSIntegerMin;

        NSString *time = [TBXML valueOfAttributeNamed:@"time" forElement:element];
		if (time)
			self.timestamp = [[time substringToIndex:10] intValue];
		
		self.user = [[TBXML valueOfAttributeNamed:@"username" forElement:element] cleanString];
		self.message = [[TBXML valueOfAttributeNamed:@"message" forElement:element] cleanString];
	}
	
	return self;
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element
{
    if ((self = [super init]))
    {
        _timestamp = NSIntegerMin;
        
        NSString *time = [element attribute:@"time"];
        if (time)
            self.timestamp = [[time substringToIndex:10] intValue];
        
        self.user = [[element attribute:@"username"] cleanString];
        self.message = [[element attribute:@"message"] cleanString];
    }
    
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	ISMSChatMessage *newChatMessage = [[ISMSChatMessage alloc] init];
	newChatMessage.timestamp = self.timestamp;
	newChatMessage.user = self.user;
	newChatMessage.message = self.message;
	
	return newChatMessage;
}

@end
