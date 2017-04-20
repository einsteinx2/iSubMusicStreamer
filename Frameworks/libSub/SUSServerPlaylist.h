//
//  SUSServerPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//


@interface SUSServerPlaylist : NSObject <NSCopying>

@property (copy) NSString *playlistId;
@property (copy) NSString *playlistName;

- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithRXMLElement:(RXMLElement *)element;

@end
