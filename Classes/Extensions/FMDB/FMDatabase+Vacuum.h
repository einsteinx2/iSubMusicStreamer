//
//  FMDatabase+Vacuum.h
//  iSub Release
//
//  Created by Benjamin Baron on 12/28/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "FMDatabase.h"

NS_ASSUME_NONNULL_BEGIN

@interface FMDatabase (Vacuum)

- (void)vacuum;

@end

NS_ASSUME_NONNULL_END
