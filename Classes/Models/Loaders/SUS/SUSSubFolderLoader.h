//
//  SUSSubFolderLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class ISMSArtist;
@interface SUSSubFolderLoader : SUSLoader

@property (nonatomic) NSUInteger albumsCount;
@property (nonatomic) NSUInteger songsCount;
@property (nonatomic) NSUInteger folderLength;

@property (copy) NSString *myId;
@property (copy) ISMSArtist *myArtist;

@end
