//
//  SUSArtistsLoader.h
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSArtistsLoader : SUSLoader

@property NSUInteger tempRecordCount;
@property (strong) NSNumber *selectedFolderId;

@end
