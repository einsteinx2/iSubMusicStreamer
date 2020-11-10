//
//  ChatMessage.h
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface ISMSChatMessage : NSObject <NSCopying>

@property NSInteger timestamp;
@property (copy) NSString *user;
@property (copy) NSString *message;

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;
- (instancetype)copyWithZone:(NSZone *)zone;

@end
