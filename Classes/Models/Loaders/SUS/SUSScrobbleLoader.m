//
//  SUSScrobbleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSScrobbleLoader.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSScrobbleLoader

- (NSURLRequest *)createRequest
{
    NSString *isSubmissionString = [NSString stringWithFormat:@"%i", self.isSubmission];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(self.aSong.songId), @"id", n2N(isSubmissionString), @"submission", nil];
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"scrobble" parameters:parameters];
    ALog(@"%@", parameters);
    return request;
}

- (void)processResponse
{
    [self informDelegateLoadingFinished];
}

@end
