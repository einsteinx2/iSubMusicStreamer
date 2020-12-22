//
//  SUSRootFoldersDAO.h
//  iSub
//
//  Created by Ben Baron on 8/21/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderManager.h"

@class ISMSFolderArtist, FMDatabase, SUSRootFoldersLoader;

@interface SUSRootFoldersDAO : NSObject <SUSLoaderManager, SUSLoaderDelegate>
{		
	NSUInteger _tempRecordCount;
    NSArray *_indexNames;
    NSArray *_indexPositions;
    NSArray *_indexCounts;
}

@property (weak) id<SUSLoaderDelegate> delegate;

@property (strong) SUSRootFoldersLoader *loader;

@property (readonly) NSUInteger count;
@property (readonly) NSUInteger searchCount;
@property (readonly) NSArray *indexNames;
@property (readonly) NSArray *indexPositions;
@property (readonly) NSArray *indexCounts;

- (NSString *)tableModifier;

@property (strong) NSNumber *selectedFolderId;
@property (readonly) BOOL isRootFolderIdCached;

+ (void)setFolderDropdownFolders:(NSDictionary *)folders;
+ (NSDictionary *)folderDropdownFolders;

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;

- (ISMSFolderArtist *)folderArtistForPosition:(NSUInteger)position;
- (void)clearSearchTable;
- (void)searchForFolderName:(NSString *)name;
- (ISMSFolderArtist *)folderArtistForPositionInSearch:(NSUInteger)position;

- (void)startLoad;
- (void)cancelLoad;

@end
