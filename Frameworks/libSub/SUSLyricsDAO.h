//
//  SUSLyricsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@class SUSLyricsLoader, FMDatabase;
@interface SUSLyricsDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property (weak) NSObject <ISMSLoaderDelegate> *delegate;
@property (strong) SUSLyricsLoader *loader;

- (id)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate;
- (NSString *)loadLyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

#pragma mark - Public DAO Methods
- (NSString *)lyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

@end
