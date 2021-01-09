//
//  ISMSLocalPlaylist.m
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSLocalPlaylist.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "FMDatabaseQueueAdditions.h"
//#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Defines.h"

@implementation ISMSLocalPlaylist

- (instancetype)initWithName:(NSString *)name md5:(NSString *)md5 count:(NSUInteger)count {
    if (self = [super init]) {
        _name = name;
        _md5 = md5;
        _count = count;
    }
    return self;
}

- (NSString *)databaseTable {
    return [NSString stringWithFormat:@"playlist%@", self.md5];
}

#pragma mark Table Cell Model

- (NSString *)primaryLabelText { return self.name; }
- (NSString *)secondaryLabelText { return self.count == 1 ? @"1 song" : [NSString stringWithFormat:@"%lu songs", (unsigned long)self.count]; }
- (NSString *)durationLabelText { return nil; }
- (NSString *)coverArtId { return nil; }
- (BOOL)isCached { return NO; }

- (void)download {
//    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
//
//    [EX2Dispatch runInBackgroundAfterDelay:0.05 block:^{
//        for (int i = 0; i < self.count; i++) {
//            [[ISMSSong songFromDbRow:i inTable:self.databaseTable inDatabaseQueue:databaseS.localPlaylistsDbQueue] addToDownloadQueue];
//        }
//
//        [EX2Dispatch runInMainThreadAsync:^{
//            [viewObjectsS hideLoadingScreen];
//        }];
//    }];
}

- (void)queue {
//    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
//    
//    [EX2Dispatch runInBackgroundAfterDelay:0.05 block:^{
//        for (int i = 0; i < self.count; i++) {
//            [[ISMSSong songFromDbRow:i inTable:self.databaseTable inDatabaseQueue:databaseS.localPlaylistsDbQueue] addToCurrentPlaylistDbQueue];
//        }
//        
//        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
//        
//        [EX2Dispatch runInMainThreadAsync:^{
//            [viewObjectsS hideLoadingScreen];
//        }];
//    }];
}

@end
