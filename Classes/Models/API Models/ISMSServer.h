//
//  ISMSServer.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define SUBSONIC @"Subsonic"

@interface ISMSServer : NSObject <NSCoding>

@property (copy) NSString *url;
@property (copy) NSString *username;
@property (copy) NSString *password;
@property (copy) NSString *type;
@property (copy) NSString *lastQueryId;
@property (copy) NSString *uuid;

@end
