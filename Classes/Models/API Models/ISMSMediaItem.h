//
//  MediaItem.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ISMSMediaItem <NSObject>

@property (copy) NSString *itemId;
@property (copy) NSString *title;

@end
