//
//  SUSScrobbleLoader.h
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSLoader.h"

@class ISMSSong;
@interface SUSScrobbleLoader : SUSLoader

@property (nonatomic, strong) ISMSSong *aSong;
@property BOOL isSubmission;
@property (nonatomic, strong) NSString *lfmAuthUrl;

@end
