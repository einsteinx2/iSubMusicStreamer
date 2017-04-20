//
//  UIDevice+Software.h
//  EX2Kit
//
//  Created by Ben Baron on 12/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (Software)

- (NSString *)systemBuild;
- (NSString *)completeVersionString;
- (BOOL)isJailbroken;
- (BOOL)isOnPhoneCall;

@end
