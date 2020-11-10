//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSSubFolderLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation SUSSubFolderLoader

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.myId) forKey:@"id"];
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
}

- (void)processResponse
{	            
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
    
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
            [self resetDb];
            self.albumsCount = 0;
            self.songsCount = 0;
            self.folderLength = 0;
            
            NSMutableArray *albums = [[NSMutableArray alloc] initWithCapacity:0];
            
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue])
                {
                    ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:e artistId:self.myArtist.artistId artistName:self.myArtist.name];
                    if (![anAlbum.title isEqualToString:@".AppleDouble"])
                    {
                        [albums addObject:anAlbum];
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
                            [self insertSongIntoFolderCache:aSong];
                            self.songsCount++;
                            self.folderLength += [aSong.duration intValue];
                        }
                    }
                }
            }];
            
            // Hack for Subsonic 4.7 breaking alphabetical order
            [albums sortUsingComparator:^NSComparisonResult(ISMSAlbum *obj1, ISMSAlbum *obj2) {
                return [obj1.title caseInsensitiveCompareWithoutIndefiniteArticles:obj2.title];
            }];
            for (ISMSAlbum *anAlbum in albums)
            {
                [self insertAlbumIntoFolderCache:anAlbum];
            }
            self.albumsCount = albums.count;
            //
            
            [self insertAlbumsCount];
            [self insertSongsCount];
            [self insertFolderLength];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}


@end
