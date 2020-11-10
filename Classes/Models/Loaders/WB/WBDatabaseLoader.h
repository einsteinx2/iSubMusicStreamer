//
//  WBDatabaseLoader.h
//  libSub
//
//  Created by Justin Hill on 1/26/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@interface WBDatabaseLoader : ISMSLoader

@property (strong) NSString *lastQueryId;
@property (strong) NSString *uuid;
@property (strong) NSString *error;
@property (strong) NSString *version;

- (id)initWithCallbackBlock:(LoaderCallback)theBlock serverUuid:(NSString *)serverUuid;

@end
