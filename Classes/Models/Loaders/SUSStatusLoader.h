//
//  SUSStatusLoader.h
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

NS_ASSUME_NONNULL_BEGIN

@interface SUSStatusLoader : SUSLoader

@property (nullable, strong) NSString *urlString;
@property (nullable, strong) NSString *username;
@property (nullable, strong) NSString *password;
@property BOOL isNewSearchAPI;
@property BOOL isVideoSupported;
@property NSUInteger majorVersion;
@property NSUInteger minorVersion;
@property (nullable, copy) NSString *versionString;

NS_ASSUME_NONNULL_END

@end
