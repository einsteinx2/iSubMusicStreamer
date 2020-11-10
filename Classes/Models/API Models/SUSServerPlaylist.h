//
//  SUSServerPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@class RXMLElement;
@interface SUSServerPlaylist : NSObject <NSCopying>

@property (copy) NSString *playlistId;
@property (copy) NSString *playlistName;

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;

@end
