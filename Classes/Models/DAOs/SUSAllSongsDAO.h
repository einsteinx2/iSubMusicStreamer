//
//  SUSAllSongsDAO.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@class FMDatabase, ISMSSong, SUSAllSongsLoader;

@interface SUSAllSongsDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>
{
	__strong NSArray *index;
}

@property (weak) id<ISMSLoaderDelegate> delegate;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) BOOL isDataLoaded;

@property (strong) SUSAllSongsLoader *loader;

- (NSArray *)index;

- (instancetype)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate;
- (void)restartLoad;
- (void)startLoad;
- (void)cancelLoad;

- (ISMSSong *)songForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForSongName:(NSString *)name;
- (ISMSSong *)songForPositionInSearch:(NSUInteger)position;

@end
