//
//  SUSQuickAlbumsLoader.m
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQuickAlbumsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation SUSQuickAlbumsLoader

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_NowPlaying;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
	NSDictionary *parameters = @{@"size":@"20", @"type":n2N(self.modifier), @"offset":[NSString stringWithFormat:@"%lu", (unsigned long)self.offset]};
    return [NSMutableURLRequest requestWithSUSAction:@"getAlbumList" parameters:parameters];
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
            self.listOfAlbums = [NSMutableArray arrayWithCapacity:0];
            [root iterate:@"albumList.album" usingBlock:^(RXMLElement *e) {
                ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:e];
                
                //Add album object to lookup dictionary and list array
                if (![anAlbum.title isEqualToString:@".AppleDouble"])
                {
                    [self.listOfAlbums addObject:anAlbum];
                }
            }];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
