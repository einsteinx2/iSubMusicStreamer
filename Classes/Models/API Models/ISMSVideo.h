//
//  Video.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSMediaItem.h"

@interface ISMSVideo : NSObject <ISMSMediaItem>

@property (copy) NSString *itemId;
@property (copy) NSString *title;

- (BOOL)isEqualToVideo:(ISMSVideo *)otherVideo;

@end
