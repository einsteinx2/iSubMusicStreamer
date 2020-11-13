//
//  SUSQuickAlbumsLoader.m
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQuickAlbumsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "NSError+ISMSError.h"
#import "ISMSAlbum.h"
#import "EX2Kit.h"

@implementation SUSQuickAlbumsLoader

#pragma mark - Lifecycle

- (SUSLoaderType)type {
    return SUSLoaderType_QuickAlbums;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest {
	NSDictionary *parameters = @{@"size":@"20", @"type":n2N(self.modifier), @"offset":[NSString stringWithFormat:@"%lu", (unsigned long)self.offset]};
    return [NSMutableURLRequest requestWithSUSAction:@"getAlbumList" parameters:parameters];
}

- (void)processResponse {
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (!root.isValid) {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    } else {
        RXMLElement *error = [root child:@"error"];
        if (error.isValid)
        {
            NSInteger code = [[error attribute:@"code"] integerValue];
            NSString *message = [error attribute:@"message"];
            [self informDelegateLoadingFailed:[NSError errorWithISMSCode:code message:message]];
        } else {
            NSMutableArray *albums = [[NSMutableArray alloc] init];
            [root iterate:@"albumList.album" usingBlock:^(RXMLElement *e) {
                ISMSAlbum *album = [[ISMSAlbum alloc] initWithRXMLElement:e];
                if (![album.title isEqualToString:@".AppleDouble"]) {
                    [albums addObject:album];
                }
            }];
            self.listOfAlbums = albums;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
