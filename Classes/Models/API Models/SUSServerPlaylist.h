//
//  SUSServerPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSTableCellModel.h"
#import "TBXML.h"

NS_ASSUME_NONNULL_BEGIN

@class RXMLElement;
NS_SWIFT_NAME(ServerPlaylist)
@interface SUSServerPlaylist : NSObject <NSCopying>

@property (copy) NSString *playlistId;
@property (copy) NSString *playlistName;

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;

@end

NS_ASSUME_NONNULL_END
