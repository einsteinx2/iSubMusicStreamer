//
//  ISMSServer.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SUBSONIC @"Subsonic"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Server)
@interface ISMSServer : NSObject <NSSecureCoding>

@property (nullable, copy) NSString *url;
@property (nullable, copy) NSString *username;
@property (nullable, copy) NSString *password;
@property (nullable, copy) NSString *type;
@property (nullable, copy) NSString *lastQueryId;
@property (nullable, copy) NSString *uuid;

@end

NS_ASSUME_NONNULL_END
