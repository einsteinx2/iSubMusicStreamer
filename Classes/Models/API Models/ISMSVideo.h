//
//  Video.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSMediaItem.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Video)
@interface ISMSVideo : NSObject <ISMSMediaItem>

@property (nullable, copy) NSString *itemId;
@property (nullable, copy) NSString *title;

- (BOOL)isEqualToVideo:(ISMSVideo *)otherVideo;

@end

NS_ASSUME_NONNULL_END
