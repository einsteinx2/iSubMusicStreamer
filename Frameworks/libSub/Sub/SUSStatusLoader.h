//
//  SUSStatusLoader.h
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStatusLoader.h"

@interface SUSStatusLoader : ISMSStatusLoader

@property (strong) NSString *urlString;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property BOOL isNewSearchAPI;
@property BOOL isVideoSupported;
@property NSUInteger majorVersion;
@property NSUInteger minorVersion;
@property (copy) NSString *versionString;

@end
