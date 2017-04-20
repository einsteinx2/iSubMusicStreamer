//
//  ISMSNetworkIndicator.h
//  iSub
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EX2NetworkIndicator : NSObject

+ (void)usingNetwork;
+ (void)doneUsingNetwork;
+ (void)goingOffline;

@end
