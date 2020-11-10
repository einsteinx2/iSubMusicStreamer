//
//  HTTPSProxyConnection.m
//  libSub
//
//  Created by Benjamin Baron on 1/5/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

static const int ddLogLevel = LOG_LEVEL_ERROR;

#import "HLSProxyConnection.h"
#import "HLSProxyResponse.h"

@implementation HLSProxyConnection

// Download the chunk from the server and reply with it
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    // Figure out the new URL
    NSString *urlString = [NSString stringWithFormat:@"%@%@", settingsS.urlString, path];
    
    // Create the response and tell it to start downloading the chunk
    DDLogVerbose(@"\n\nHTTPProxyConnection: starting proxy connection for %@", urlString);
    HLSProxyResponse *response = [[HLSProxyResponse alloc] initWithConnection:self];
    [response startProxyDownload:[NSURL URLWithString:urlString]];
    
    return response;
}

@end
