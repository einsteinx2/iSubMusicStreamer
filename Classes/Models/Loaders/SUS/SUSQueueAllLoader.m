//
//  SUSQueueAllLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSQueueAllLoader.h"
#import "NSMutableURLRequest+SUS.h"

@implementation SUSQueueAllLoader

- (void)loadAlbumFolder
{		
	if (self.isCancelled)
		return;
	
	NSString *folderId = [self.folderIds objectAtIndexSafe:0];
	//DLog(@"Loading folderid: %@", folderId);
    
	NSDictionary *parameters = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
}

- (void)process
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
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue])
                {
                    ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:e artistId:self.myArtist.artistId artistName:self.myArtist.name];
                    if (![anAlbum.title isEqualToString:@".AppleDouble"])
                    {
                        [self.listOfAlbums addObject:anAlbum];
                    }
                }
                else
                {
                    ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                    if (aSong.path && (settingsS.isVideoSupported || !aSong.isVideo))
                    {
                        // Fix for pdfs showing in directory listing
                        if (![aSong.suffix.lowercaseString isEqualToString:@"pdf"])
                        {
                            [self.listOfSongs addObject:aSong];
                        }
                    }
                }
            }];
		}
	}	
}

@end
