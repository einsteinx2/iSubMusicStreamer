//
//  ChatMessage.h
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RXMLElement;
NS_SWIFT_NAME(ChatMessage)
@interface ISMSChatMessage : NSObject <NSCopying>

@property NSInteger timestamp;
@property (copy) NSString *user;
@property (copy) NSString *message;

- (instancetype)initWithRXMLElement:(RXMLElement *)element;
- (instancetype)copyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END
