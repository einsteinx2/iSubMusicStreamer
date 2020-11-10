//
//  ISMSScrobbleLoader.h
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"
@interface ISMSScrobbleLoader : ISMSLoader

@property (nonatomic, strong) ISMSSong *aSong;
@property BOOL isSubmission;
@property (nonatomic, strong) NSString *lfmAuthUrl;

@end

#import "SUSScrobbleLoader.h"
