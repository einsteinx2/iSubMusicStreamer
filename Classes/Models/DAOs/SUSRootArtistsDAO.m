//
//  SUSRootArtistsDAO.m
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSRootArtistsDAO.h"
#import "SUSRootArtistsLoader.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@interface SUSRootArtistsDAO() {
    NSNumber *_selectedFolderId;
}
@end

@implementation SUSRootArtistsDAO

#pragma mark Lifecycle

- (instancetype)initWithDelegate:(id <SUSLoaderDelegate>)delegate {
    if ((self = [super init])) {
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc {
    [_loader cancelLoad];
    _loader.delegate = nil;
}

#pragma mark Properties

- (FMDatabaseQueue *)dbQueue {
    return databaseS.albumListCacheDbQueue;
}

- (NSString *)tableModifier {
    NSString *tableModifier = @"_all";
    if (self.selectedFolderId != nil && [self.selectedFolderId intValue] != -1) {
        tableModifier = [NSString stringWithFormat:@"_%@", [self.selectedFolderId stringValue]];
    }
    return tableModifier;
}

#pragma mark Private Methods

- (BOOL)addRootArtistToCache:(NSString*)artistId name:(NSString*)name {
    __block BOOL hadError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"INSERT INTO rootArtistNameCache%@ VALUES (?, ?)", self.tableModifier];
        [db executeUpdate:query, artistId, [name cleanString]];
        hadError = [db hadError];
    }];
    return !hadError;
}

- (NSUInteger)rootArtistCount {
    NSString *query = [NSString stringWithFormat:@"SELECT count FROM rootArtistCount%@ LIMIT 1", self.tableModifier];
    return [self.dbQueue intForQuery:query];
}

- (NSUInteger)rootArtistSearchCount {
    NSString *query = @"SELECT count(*) FROM rootArtistNameSearch";
    return [self.dbQueue intForQuery:query];
}

- (NSArray *)rootArtistIndexNames {
    __block NSMutableArray *names = [NSMutableArray arrayWithCapacity:0];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootArtistIndexCache%@", self.tableModifier];
        FMResultSet *result = [db executeQuery:query];
        while ([result next]) {
            NSString *name = [result stringForColumn:@"name"];
            [names addObject:name];
        }
        [result close];
    }];
    return [NSArray arrayWithArray:names];
}

- (NSArray *)rootArtistIndexPositions {
    __block NSMutableArray *positions = [NSMutableArray arrayWithCapacity:0];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootArtistIndexCache%@", self.tableModifier];
        FMResultSet *result = [db executeQuery:query];
        while ([result next]) {
            @autoreleasepool {
                NSNumber *position = @([result intForColumn:@"position"]);
                [positions addObject:position];
            }
        }
        [result close];
    }];
    return positions.count == 0 ? nil : positions;
}

- (NSArray *)rootArtistIndexCounts {
    __block NSMutableArray *counts = [NSMutableArray arrayWithCapacity:0];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootArtistIndexCache%@", self.tableModifier];
        FMResultSet *result = [db executeQuery:query];
        while ([result next]) {
            @autoreleasepool {
                NSNumber *folderCount = @([result intForColumn:@"count"]);
                [counts addObject:folderCount];
            }
        }
        [result close];
    }];
    return counts.count == 0 ? nil : counts;
}

- (ISMSTagArtist *)rootTagArtistForPosition:(NSUInteger)position {
    __block ISMSTagArtist *tagArtist = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM rootArtistCache%@ WHERE ROWID = ?", self.tableModifier];
        FMResultSet *result = [db executeQuery:query, @(position)];
        if ([result next]) {
            tagArtist = [[ISMSTagArtist alloc] initWithResult:result];
        }
        [result close];
    }];
    return tagArtist;
}

- (ISMSTagArtist *)rootTagArtistForPositionInSearch:(NSUInteger)position {
    __block ISMSTagArtist *tagArtist = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM rootArtistNameSearch WHERE ROWID = ?";
        FMResultSet *result = [db executeQuery:query, @(position)];
        if ([result next]) {
            tagArtist = [[ISMSTagArtist alloc] initWithResult:result];
        }
        [result close];
    }];
    return tagArtist;
}

- (void)rootArtistClearSearch {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if ([db tableExists:@"rootArtistNameSearch"]) {
            [db executeUpdate:@"DELETE FROM rootArtistNameSearch"];
        } else {
            // Inialize the search DB
            NSString *query = @"DROP TABLE IF EXISTS rootArtistNameSearch";
            [db executeUpdate:query];
            query = @"CREATE TEMPORARY TABLE rootArtistNameSearch (id TEXT PRIMARY KEY, name TEXT)";
            [db executeUpdate:query];
        }
    }];
}

- (void)rootArtistPerformSearch:(NSString *)name {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        // Inialize the search DB
        NSString *query = @"DROP TABLE IF EXISTS rootArtistNameSearch";
        [db executeUpdate:query];
        query = @"CREATE TEMPORARY TABLE rootArtistNameSearch (id TEXT PRIMARY KEY, name TEXT)";
        [db executeUpdate:query];
        
        // Perform the search
        query = [NSString stringWithFormat:@"INSERT INTO rootArtistNameSearch SELECT * FROM rootArtistNameCache%@ WHERE name LIKE ? LIMIT 100", self.tableModifier];
        [db executeUpdate:query, [NSString stringWithFormat:@"%%%@%%", name]];
        if ([db hadError]) {
            //DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
        }
    }];
}

- (BOOL)rootArtistIsFolderCached {
    NSString *query = [NSString stringWithFormat:@"rootArtistIndexCache%@", self.tableModifier];
    return [self.dbQueue tableExists:query];
}

#pragma mark Public DAO Methods

+ (void)setFolderDropdownFolders:(NSDictionary *)artists {
    [databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"DROP TABLE IF EXISTS rootArtistDropdownCache"];
        [db executeUpdate:@"CREATE TABLE rootArtistDropdownCache (id INTEGER, name TEXT)"];
        
        for (NSNumber *artistId in artists.allKeys) {
            [db executeUpdate:@"INSERT INTO rootArtistDropdownCache VALUES (?, ?)", artistId, artists[artistId]];
        }
    }];
}

+ (NSDictionary *)folderDropdownFolders {
    if (![databaseS.albumListCacheDbQueue tableExists:@"rootFolderDropdownCache"]) return nil;
    
    __block NSMutableDictionary *folders = [NSMutableDictionary dictionaryWithCapacity:0];
    [databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT * FROM rootArtistDropdownCache"];
        while ([result next]) {
            @autoreleasepool  {
                NSNumber *folderId = @([result intForColumn:@"id"]);
                NSString *folderName = [result stringForColumn:@"name"];
                [folders setObject:folderName forKey:folderId];
            }
        }
        [result close];
    }];
    return folders;
}

- (NSNumber *)selectedFolderId {
    @synchronized(self) {
        return _selectedFolderId ? _selectedFolderId : @(-1);
    }
}

- (void)setSelectedFolderId:(NSNumber *)selectedFolderId {
    @synchronized(self) {
        _selectedFolderId = selectedFolderId;
        _indexNames = nil;
        _indexCounts = nil;
        _indexPositions = nil;
    }
}

- (BOOL)isRootArtistFolderIdCached {
    return [self rootArtistIsFolderCached];
}

- (NSUInteger)count {
    return [self rootArtistCount];
}

- (NSUInteger)searchCount {
    return [self rootArtistSearchCount];
}

- (NSArray *)indexNames {
    if (!_indexNames || _indexNames.count == 0) {
        _indexNames = [self rootArtistIndexNames];
    }
    return _indexNames;
}

- (NSArray *)indexPositions {
    if (!_indexPositions || _indexPositions.count == 0) {
        _indexPositions = [self rootArtistIndexPositions];
    }
    return _indexPositions;
}

- (NSArray *)indexCounts {
    if (!_indexCounts) {
        _indexCounts = [self rootArtistIndexCounts];
    }
    return _indexCounts;
}

- (ISMSTagArtist *)tagArtistForPosition:(NSUInteger)position {
    return [self rootTagArtistForPosition:position];
}

- (ISMSTagArtist *)tagArtistForPositionInSearch:(NSUInteger)position {
    return [self rootTagArtistForPositionInSearch:position];
}

- (void)clearSearchTable {
    [self rootArtistClearSearch];
}

- (void)searchForArtistName:(NSString *)name {
    [self rootArtistPerformSearch:name];
}

#pragma mark Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSRootArtistsLoader alloc] initWithDelegate:self];
    self.loader.selectedFolderId = self.selectedFolderId;
    [self.loader startLoad];
}

- (void)cancelLoad {
    [self.loader cancelLoad];
    self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    self.loader.delegate = nil;
    self.loader = nil;
    
    if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)]) {
        [self.delegate loadingFailed:nil withError:error];
    }
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    self.loader.delegate = nil;
    self.loader = nil;
        
    _indexNames = nil;
    _indexPositions = nil;
    _indexCounts = nil;
    
    // Force all subfolders to reload
    [databaseS resetFolderCache];
    
    if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
        [self.delegate loadingFinished:nil];
    }
}

@end
