//
//  SUSLyricsLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSLyricsLoader : SUSLoader

@property (copy) NSString *artist;
@property (copy) NSString *title;

@property (copy) NSString *loadedLyrics;

@end
