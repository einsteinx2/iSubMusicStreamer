//
//  PMSLoginLoader.h
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

@interface PMSLoginLoader : ISMSLoader

@property (strong) NSString *urlString;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property (strong) NSString *sessionId;

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate urlString:(NSString *)theUrlString username:(NSString *)theUsername password:(NSString *)thePassword;

@end
