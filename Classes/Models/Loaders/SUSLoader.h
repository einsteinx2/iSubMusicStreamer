//
//  SUSLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SUSLoaderDelegate.h"

typedef enum {
    SUSLoaderType_Generic = 0,
    SUSLoaderType_RootFolders,
    SUSLoaderType_SubFolders,
    SUSLoaderType_AllSongs,
    SUSLoaderType_Chat,
    SUSLoaderType_Lyrics,
    SUSLoaderType_CoverArt,
    SUSLoaderType_ServerPlaylist,
    SUSLoaderType_NowPlaying,
    SUSLoaderType_Status,
    SUSLoaderType_Login,
    SUSLoaderType_HLS,
    SUSLoaderType_QuickAlbums,
    SUSLoaderType_DropdownFolder,
    SUSLoaderType_ServerShuffle,
    SUSLoaderType_Scrobble
} SUSLoaderType;

@class SUSLoader;

NS_ASSUME_NONNULL_BEGIN

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^SUSLoaderCallback)(BOOL success, NSError * _Nullable error, SUSLoader *loader);

@interface SUSLoader : NSObject

@property (nullable, weak) NSObject<SUSLoaderDelegate> *delegate;
@property (nullable, copy) SUSLoaderCallback callbackBlock;

@property (readonly) SUSLoaderType type;

@property (nullable, strong, readonly) NSData *receivedData;

+ (NSURLSession *)sharedSession;

- (void)setup; // Override this
- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)theDelegate;
- (instancetype)initWithCallbackBlock:(SUSLoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;
- (NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)informDelegateLoadingFailed:(nullable NSError *)error;
- (void)informDelegateLoadingFinished;

@end

NS_ASSUME_NONNULL_END
