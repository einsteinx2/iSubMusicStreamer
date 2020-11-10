//
//  SUSQuickAlbumsLoader.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSQuickAlbumsLoader : SUSLoader

@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSString *modifier;
@property NSUInteger offset;

@end
