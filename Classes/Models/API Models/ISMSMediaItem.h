//
//  MediaItem.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(MediaItem)
@protocol ISMSMediaItem <NSObject>

@property (nullable, copy) NSString *itemId;
@property (nullable, copy) NSString *title;

@end

NS_ASSUME_NONNULL_END
