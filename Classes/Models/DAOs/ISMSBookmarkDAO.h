//
//  ISMSBookmarkDAO.h
//  iSub
//
//  Created by Benjamin Baron on 11/21/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ISMSSong;
@interface ISMSBookmarkDAO : NSObject

+ (void)createBookmarkForSong:(ISMSSong *)song name:(NSString *)name bookmarkPosition:(NSUInteger)position bytePosition:(NSUInteger)bytePosition;

@end

NS_ASSUME_NONNULL_END
