//
//  UIDevice+Info.h
//  iSub
//
//  Created by Benjamin Baron on 12/6/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (Info)
+ (BOOL)isPad;
+ (BOOL)isSmall;
+ (NSString *)platform;
+ (NSString *)systemBuild;
+ (NSString *)completeVersionString;
@end

NS_ASSUME_NONNULL_END
