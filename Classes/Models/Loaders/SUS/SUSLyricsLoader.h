//
//  SUSLyricsLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderNew.h"

@interface SUSLyricsLoader : ISMSLoaderNew

@property (copy) NSString *artist;
@property (copy) NSString *title;

@property (copy) NSString *loadedLyrics;

@end
