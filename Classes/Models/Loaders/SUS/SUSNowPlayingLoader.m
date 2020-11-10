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

- (ISMSLoaderType)type
{
    return ISMSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
	return [NSMutableURLRequest requestWithSUSAction:@"getNowPlaying" parameters:nil];
}

- (void)processResponse
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
        }
        else
        {
            self.nowPlayingSongDicts = [[NSMutableArray alloc] initWithCapacity:0];
            
            // TODO: Stop using a dictionary for this
            [root iterate:@"nowPlaying.entry" usingBlock:^(RXMLElement *e) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
                
                [dict setObjectSafe:[[ISMSSong alloc] initWithRXMLElement:e] forKey:@"song"];
                [dict setObjectSafe:[e attribute:@"username"] forKey:@"username"];
                [dict setObjectSafe:[e attribute:@"minutesAgo"] forKey:@"minutesAgo"];
                [dict setObjectSafe:[e attribute:@"playerId"] forKey:@"playerId"];
                [dict setObjectSafe:[e attribute:@"playerName"] forKey:@"playerName"];
                
                [self.nowPlayingSongDicts addObject:dict];
            }];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
