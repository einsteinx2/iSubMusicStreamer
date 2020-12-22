//
//  SUSSubFolderLoader.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class ISMSFolderArtist;
@interface SUSSubFolderLoader : SUSLoader

@property (nonatomic) NSUInteger folderAlbumsCount;
@property (nonatomic) NSUInteger songsCount;
@property (nonatomic) NSUInteger folderLength;

@property (copy) NSString *folderId;
@property (copy) ISMSFolderArtist *folderArtist;

@end
