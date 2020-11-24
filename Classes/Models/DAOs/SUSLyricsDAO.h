//
//  SUSLyricsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

NS_ASSUME_NONNULL_BEGIN

@class SUSLyricsLoader, FMDatabase;
@interface SUSLyricsDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>

@property (nullable, weak) NSObject <SUSLoaderDelegate> *delegate;
@property (nullable, strong) SUSLyricsLoader *loader;

- (instancetype)initWithDelegate:(nullable NSObject <SUSLoaderDelegate> *)theDelegate;
- (NSString *)loadLyricsForArtist:(nullable NSString *)artist andTitle:(nullable NSString *)title;
- (nullable NSString *)lyricsForArtist:(nullable NSString *)artist andTitle:(nullable NSString *)title;

@end

NS_ASSUME_NONNULL_END
