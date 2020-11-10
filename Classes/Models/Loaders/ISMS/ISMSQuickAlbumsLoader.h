//
//  ISMSQuickAlbumsLoader.h
//  libSub
//
//  Created by Justin Hill on 1/31/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@interface ISMSQuickAlbumsLoader : ISMSLoader

@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSString *modifier;
@property NSUInteger offset;

@end

#import "SUSQuickAlbumsLoader.h"
