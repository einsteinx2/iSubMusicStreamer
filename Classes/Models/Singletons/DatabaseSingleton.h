//
//  DatabaseSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_DatabaseSingleton_h
#define iSub_DatabaseSingleton_h

#import <Foundation/Foundation.h>

#define databaseS ((DatabaseSingleton *)[DatabaseSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

@class FMDatabase, FMDatabaseQueue, ISMSFolderArtist, ISMSSong;

NS_SWIFT_NAME(DatabaseOld)
@interface DatabaseSingleton : NSObject

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());
+ (void)setAllSongsToBackup;
+ (void)setAllSongsToNotBackup;

- (void)setupDatabases;
- (void)closeAllDatabases;

- (nullable NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column;
- (nullable NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column;

- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column NS_SWIFT_NAME(sectionInfoFromOrderColumnTable(_:databaseQueue:column:));
- (NSArray *)sectionInfoFromOrderColumnTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column NS_SWIFT_NAME(sectionInfoFromOrderColumnTable(_:database:column:));

- (void)shufflePlaylist;

- (void)updateTableDefinitions;

@end

NS_ASSUME_NONNULL_END

#endif
