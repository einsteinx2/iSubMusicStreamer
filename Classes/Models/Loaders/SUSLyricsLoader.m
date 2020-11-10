//
//  SUSLyricsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "NSError+ISMSError.h"
#import "Defines.h"
#import "EX2Kit.h"

@implementation SUSLyricsLoader

- (SUSLoaderType)type {
    return SUSLoaderType_Lyrics;
}

- (NSURLRequest *)createRequest {
    return [NSMutableURLRequest requestWithSUSAction:@"getLyrics" parameters:@{@"artist": n2N(self.artist), @"title": n2N(self.title)}];
}

- (void)processResponse {
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid]) {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
    } else {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid]) {
            NSInteger code = [[error attribute:@"code"] integerValue];
            NSString *message = [error attribute:@"message"];
            [self informDelegateLoadingFailed:[NSError errorWithISMSCode:code message:message]];
            
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
        } else {
            RXMLElement *lyrics = [root child:@"lyrics"];
            if ([lyrics isValid]) {
                self.loadedLyrics = [lyrics text];
                if ([self.loadedLyrics hasValue]) {
                    [self insertLyricsIntoDb];
                    [self informDelegateLoadingFinished];
                    
                    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsDownloaded];
                } else {
                    self.loadedLyrics = nil;
                    NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsFound];
                    [self informDelegateLoadingFailed:error];
                }
            } else {
                self.loadedLyrics = nil;
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:error];
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
            }
        }
    }
}

- (void)insertLyricsIntoDb {
	[databaseS.lyricsDbQueue inDatabase:^(FMDatabase *db) {
		 [db executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", self.artist, self.title, self.loadedLyrics];
         if ([db hadError]) {
			 DLog(@"Err inserting lyrics %d: %@", [db lastErrorCode], [db lastErrorMessage]);
         }
	 }];
}

- (void)informDelegateLoadingFailed:(NSError *)error {
    [super informDelegateLoadingFailed:error];
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
}

@end
