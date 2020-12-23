//
//  SUSNowPlayingLoader.m
//  iSub
//
//  Created by Ben Baron on 1/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSNowPlayingLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "NSError+ISMSError.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation SUSNowPlayingLoader

- (SUSLoaderType)type {
    return SUSLoaderType_NowPlaying;
}

- (NSURLRequest *)createRequest {
	return [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying" parameters:nil];
}

- (void)processResponse {
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (!root.isValid) {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    } else {
        RXMLElement *error = [root child:@"error"];
        if (error.isValid) {
            NSInteger code = [[error attribute:@"code"] integerValue];
            NSString *message = [error attribute:@"message"];
            [self informDelegateLoadingFailed:[NSError errorWithISMSCode:code message:message]];
        } else {
            NSMutableArray *songDicts = [[NSMutableArray alloc] init];
            
            // TODO: Stop using a dictionary for this
            [root iterate:@"nowPlaying.entry" usingBlock:^(RXMLElement *e) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                dict[@"song"] = [[ISMSSong alloc] initWithRXMLElement:e];
                dict[@"username"] = [e attribute:@"username"];
                dict[@"minutesAgo"] = [e attribute:@"minutesAgo"];
                dict[@"playerId"] = [e attribute:@"playerId"];
                dict[@"playerName"] = [e attribute:@"playerName"];
                [songDicts addObject:dict];
            }];
            self.nowPlayingSongDicts = songDicts;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
