//
//  SUSRootArtistsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class ISMSTagArtist, FMDatabase, SUSRootArtistsLoader;

@interface SUSRootArtistsDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate> {
    NSUInteger _tempRecordCount;
    NSArray *_indexNames;
    NSArray *_indexPositions;
    NSArray *_indexCounts;
}

@property (weak) id<SUSLoaderDelegate> delegate;

@property (strong) SUSRootArtistsLoader *loader;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *indexNames;
@property (readonly) NSArray *indexPositions;
@property (readonly) NSArray *indexCounts;

- (NSString *)tableModifier;

@property NSInteger selectedFolderId;
@property (readonly) BOOL isRootArtistFolderIdCached; 

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)delegate;

- (ISMSTagArtist *)tagArtistForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForArtistName:(NSString *)name;
- (ISMSTagArtist *)tagArtistForPositionInSearch:(NSUInteger)position;

- (void)startLoad;
- (void)cancelLoad;

@end
