//
//  ISMSTableCellModel.h
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TableCellModel)
@protocol ISMSTableCellModel <NSObject>

@property (nullable, readonly, copy) NSString *primaryLabelText;
@property (nullable, readonly, copy) NSString *secondaryLabelText;
@property (nullable, readonly, copy) NSString *durationLabelText;
@property (nullable, readonly, copy) NSString *coverArtId;
@property (readonly) BOOL isCached;

- (void)download;
- (void)queue;

@end

NS_ASSUME_NONNULL_END
