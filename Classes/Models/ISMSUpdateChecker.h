//
//  ISMSUpdateChecker.h
//  iSub
//
//  Created by Ben Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISMSUpdateChecker : NSObject

@property (strong) NSMutableData *receivedData;
@property (strong) NSURLRequest *request;
@property (strong) NSURLConnection *connection;

@property (copy) NSString *theNewVersion;
@property (copy) NSString *message;

- (void)checkForUpdate;

@end