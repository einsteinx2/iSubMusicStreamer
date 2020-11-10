//
//  SUSNowPlayingLoader.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingLoader.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSNowPlayingLoader

#pragma mark - Lifecycle

- (SUSLoaderType)type {
    return SUSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest {
	return [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying" parameters:nil];
}

- (void)processResponse {
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid]) {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    } else {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid]) {
            NSInteger code = [[error attribute:@"code"] integerValue];
            NSString *message = [error attribute:@"message"];
            [self informDelegateLoadingFailed:[NSError errorWithISMSCode:code message:message]];
        } else {
            NSMutableArray *songDicts = [[NSMutableArray alloc] init];
            
            // TODO: Stop using a dictionary for this
            [root iterate:@"nowPlaying.entry" usingBlock:^(RXMLElement *e) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                [dict setObjectSafe:[[ISMSSong alloc] initWithRXMLElement:e] forKey:@"song"];
                [dict setObjectSafe:[e attribute:@"username"] forKey:@"username"];
                [dict setObjectSafe:[e attribute:@"minutesAgo"] forKey:@"minutesAgo"];
                [dict setObjectSafe:[e attribute:@"playerId"] forKey:@"playerId"];
                [dict setObjectSafe:[e attribute:@"playerName"] forKey:@"playerName"];
                [songDicts addObject:dict];
            }];
            self.nowPlayingSongDicts = songDicts;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
