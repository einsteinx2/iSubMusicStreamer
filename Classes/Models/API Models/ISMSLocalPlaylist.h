//
//  ISMSLocalPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSTableCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ISMSLocalPlaylist : NSObject<ISMSTableCellModel>

@property (copy) NSString *name;
@property (copy) NSString *md5;
@property NSUInteger count;
@property (readonly) NSString *databaseTable;

- (instancetype)initWithName:(NSString *)name md5:(NSString *)md5 count:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
