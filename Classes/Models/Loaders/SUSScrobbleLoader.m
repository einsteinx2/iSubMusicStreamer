//
//  SUSScrobbleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSScrobbleLoader.h"
#import "NSMutableURLRequest+SUS.h"
//#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Defines.h"
#import "Swift.h"

@implementation SUSScrobbleLoader

- (SUSLoaderType)type {
    return SUSLoaderType_Scrobble;
}

- (NSURLRequest *)createRequest {
    NSString *isSubmissionString = [NSString stringWithFormat:@"%i", self.isSubmission];
    NSDictionary *parameters = @{@"id": @(self.aSong.songId), @"submission": n2N(isSubmissionString)};
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"scrobble" parameters:parameters];
    return request;
}

- (void)processResponse {
    [self informDelegateLoadingFinished];
}

@end
