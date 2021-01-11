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
    SUSLoaderType_Generic         =  0,
    SUSLoaderType_RootFolders     =  1,
    SUSLoaderType_SubFolders      =  2,
    SUSLoaderType_AllSongs        =  3,
    SUSLoaderType_Chat            =  4,
    SUSLoaderType_Lyrics          =  5,
    SUSLoaderType_CoverArt        =  6,
    SUSLoaderType_ServerPlaylists =  7,
    SUSLoaderType_NowPlaying      =  8,
    SUSLoaderType_Status          =  9,
    SUSLoaderType_Login           = 10,
    SUSLoaderType_HLS             = 11,
    SUSLoaderType_QuickAlbums     = 12,
    SUSLoaderType_DropdownFolder  = 13,
    SUSLoaderType_ServerShuffle   = 14,
    SUSLoaderType_Scrobble        = 15,
    SUSLoaderType_RootArtists     = 16,
    SUSLoaderType_TagArtist       = 17,
    SUSLoaderType_TagAlbum        = 18,
    SUSLoaderType_ServerPlaylist  = 19
} SUSLoaderType;

@class SUSLoader;

NS_ASSUME_NONNULL_BEGIN

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallback)(BOOL success, NSError * _Nullable error);

@interface SUSLoader : NSObject

@property (nullable, weak) NSObject<SUSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callback;

@property (readonly) SUSLoaderType type;

@property (nullable, strong, readonly) NSData *receivedData;

+ (NSURLSession *)sharedSession;

- (void)setup; // Override this
- (instancetype)initWithDelegate:(nullable NSObject<SUSLoaderDelegate> *)delegate;
- (instancetype)initWithCallback:(nullable LoaderCallback)callback;

- (void)startLoad;
- (void)cancelLoad;
- (nullable NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)informDelegateLoadingFailed:(nullable NSError *)error;
- (void)informDelegateLoadingFinished;

@end

NS_ASSUME_NONNULL_END
