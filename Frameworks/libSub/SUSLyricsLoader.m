//
//  SUSLyricsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation SUSLyricsLoader

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.lyricsDbQueue;
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Lyrics;
}

- (NSURLRequest *)createRequest
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(self.artist), @"artist", n2N(self.title), @"title", nil];
    return [NSMutableURLRequest requestWithSUSAction:@"getLyrics" parameters:parameters];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    [super connection:theConnection didFailWithError:error];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
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
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
            
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
        }
        else
        {
            RXMLElement *lyrics = [root child:@"lyrics"];
            if ([lyrics isValid])
            {
                self.loadedLyrics = [lyrics text];
                if ([self.loadedLyrics hasValue])
                {
                    self.loadedLyrics = nil;
                    NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsFound];
                    [self informDelegateLoadingFailed:error];
                }
                else
                {
                    [self insertLyricsIntoDb];
                    [self informDelegateLoadingFinished];
                    
                    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsDownloaded];
                }
            }
            else
            {
                self.loadedLyrics = nil;
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:error];
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
            }
        }
    }
}

- (void)insertLyricsIntoDb
{
	[self.dbQueue inDatabase:^(FMDatabase *db)
	 {
		 [db executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", self.artist, self.title, self.loadedLyrics];
		 if ([db hadError]) 
			 DLog(@"Err inserting lyrics %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	 }];
}

@end
