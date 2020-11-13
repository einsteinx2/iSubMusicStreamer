//
//  ISMSUpdateChecker.h
//  iSub
//
//  Created by Ben Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISMSUpdateChecker : NSObject

@property (copy) NSString *theNewVersion;
@property (copy) NSString *message;

- (void)checkForUpdate;

@end
