//
//  NSString+SHA1.h
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (SHA1)

+ (NSString *)sha1:(NSString*)string;
- (NSString *)sha1;

@end
