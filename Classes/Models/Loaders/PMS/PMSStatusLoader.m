//
//  PMSStatusLoader.m
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSStatusLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation PMSStatusLoader

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithPMSAction:@"status"];
}

- (void)processResponse
{
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
    
    self.receivedData = nil;
	self.connection = nil;
	
	NSDictionary *response = [[[SBJsonParser alloc] init] objectWithString:responseString];
    
    self.error = N2n([response objectForKey:@"error"]);
    if (!response || self.error)
    {
        [self informDelegateLoadingFailed:nil];
    }
    else
    {
        NSDictionary *status = [response objectForKey:@"status"];
        self.version = [status objectForKey:@"version"];
        
        // Notify the delegate that the loading is finished
        [self informDelegateLoadingFinished];
    }
}

@end
