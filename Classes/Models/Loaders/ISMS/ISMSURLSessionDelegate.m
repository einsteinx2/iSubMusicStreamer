//
//  ISMSURLSessionDelegate.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSURLSessionDelegate.h"

@implementation ISMSURLSessionDelegate

#pragma mark NSURLSessionDelegate

// Allow self-signed SSL certificates
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
  if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
      NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
      completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
  }
}

@end
