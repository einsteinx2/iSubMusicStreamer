//
//  FMDatabase+Vacuum.m
//  iSub
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "FMDatabase+Vacuum.h"

@implementation FMDatabase(Vaccum)

- (void)vacuum {
    [self executeUpdate:@"VACUUM"];
}

@end
