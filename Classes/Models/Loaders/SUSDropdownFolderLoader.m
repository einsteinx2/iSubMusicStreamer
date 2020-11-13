//
//  SUSDropdownFolderLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSDropdownFolderLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "NSError+ISMSError.h"

@implementation SUSDropdownFolderLoader

- (SUSLoaderType)type {
    return SUSLoaderType_DropdownFolder;
}

- (NSURLRequest *)createRequest {
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicFolders" parameters:nil];
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
            NSMutableDictionary *musicFolders = [@{@-1: @"All Folders"} mutableCopy];
            [root iterate:@"musicFolders.musicFolder" usingBlock:^(RXMLElement *e) {
                NSNumber *folderId = @([[e attribute:@"id"] intValue]);
                musicFolders[folderId] = [e attribute:@"name"];
            }];
            self.updatedfolders = musicFolders;
            [self informDelegateLoadingFinished];
        }
    }
}

@end
