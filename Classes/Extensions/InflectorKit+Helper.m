//
//  InflectorKit+Helper.m
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

#import "InflectorKit+Helper.h"
#import <InflectorKit.h>

@implementation NSString(Helper)

- (NSString *)pluralize:(NSInteger)count {
    return count == 1 ? self : self.pluralizedString;
}

@end
