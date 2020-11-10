//
//  NSString+cleanCredentialsForLog.h
//  libSub
//
//  Created by Benjamin Baron on 2/27/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (cleanCredentialsForLog)

// Removes username and password for logging purposes
- (NSString *)cleanCredentialsForLog;

@end
