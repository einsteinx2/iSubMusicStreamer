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
#import "EX2Kit.h"
#import "Defines.h"
#import "Swift.h"

@implementation SUSQuickAlbumsLoader

- (SUSLoaderType)type {
    return SUSLoaderType_QuickAlbums;
}

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
        if (error.isValid) {
            [self informDelegateLoadingFailed:[NSError errorWithSubsonicXMLResponse:error]];
        } else {
            NSMutableArray *folderAlbums = [[NSMutableArray alloc] init];
            [root iterate:@"albumList.album" usingBlock:^(RXMLElement *e) {
                ISMSFolderAlbum *folderAlbum = [[ISMSFolderAlbum alloc] initWithElement:e];
                if (![folderAlbum.title isEqualToString:@".AppleDouble"]) {
                    [folderAlbums addObject:folderAlbum];
                }
            }];
            self.folderAlbums = folderAlbums;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
