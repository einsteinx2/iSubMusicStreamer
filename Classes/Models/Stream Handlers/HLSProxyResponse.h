//
//  HLSProxyResponse.h
//  libSub
//
//  Created by Benjamin Baron on 1/5/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "HTTPResponse.h"

@class HTTPConnection;
@interface HLSProxyResponse : NSObject <HTTPResponse>

@property (nonatomic, strong) HTTPConnection *serverConnection;

- (id)initWithConnection:(HTTPConnection *)serverConnection;
- (void)startProxyDownload:(NSURL *)url;

@end
