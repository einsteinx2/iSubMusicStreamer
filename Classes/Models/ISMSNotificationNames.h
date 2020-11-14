//
//  ISMSNotificationNames.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const ISMSNotification_SongPlaybackStarted;
extern NSString * const ISMSNotification_SongPlaybackPaused;
extern NSString * const ISMSNotification_SongPlaybackEnded;
extern NSString * const ISMSNotification_SongPlaybackFailed;

extern NSString * const ISMSNotification_AlbumArtLargeDownloaded;

extern NSString * const ISMSNotification_ServerSwitched;
extern NSString * const ISMSNotification_ServerCheckPassed;
extern NSString * const ISMSNotification_ServerCheckFailed;

extern NSString * const ISMSNotification_LyricsDownloaded;
extern NSString * const ISMSNotification_LyricsFailed;

extern NSString * const ISMSNotification_RepeatModeChanged;

extern NSString * const ISMSNotification_BassEffectPresetLoaded;

extern NSString * const ISMSNotification_CurrentPlaylistOrderChanged;
extern NSString * const ISMSNotification_CurrentPlaylistShuffleToggled;
extern NSString * const ISMSNotification_CurrentPlaylistIndexChanged;
extern NSString * const ISMSNotification_CurrentPlaylistSongsQueued;

extern NSString * const ISMSNotification_AllSongsLoadingArtists;
extern NSString * const ISMSNotification_AllSongsLoadingAlbums;
extern NSString * const ISMSNotification_AllSongsSorting;
extern NSString * const ISMSNotification_AllSongsArtistName;
extern NSString * const ISMSNotification_AllSongsAlbumName;
extern NSString * const ISMSNotification_AllSongsSongName;
extern NSString * const ISMSNotification_AllSongsLoadingFinished;

extern NSString * const ISMSNotification_SongCachingEnabled;
extern NSString * const ISMSNotification_SongCachingDisabled;

extern NSString * const ISMSNotification_ShowPlayer;

extern NSString * const ISMSNotification_CacheQueueStarted;
extern NSString * const ISMSNotification_CacheQueueStopped;
extern NSString * const ISMSNotification_CacheQueueSongDownloaded;
extern NSString * const ISMSNotification_CacheQueueSongFailed;
extern NSString * const ISMSNotification_StreamHandlerSongDownloaded;
extern NSString * const ISMSNotification_StreamHandlerSongFailed;

extern NSString * const ISMSNotification_CacheSizeChecked;

extern NSString * const ISMSNotification_EnteringOfflineMode;
extern NSString * const ISMSNotification_EnteringOnlineMode;

extern NSString * const ISMSNotification_BassInitialized;
extern NSString * const ISMSNotification_BassFreed;

extern NSString * const ISMSNotification_LargeSongInfoToggle;

extern NSString * const ISMSNotification_JukeboxEnabled;
extern NSString * const ISMSNotification_JukeboxDisabled;

extern NSString * const ISMSNotification_JukeboxSongInfo;

extern NSString * const ISMSNotification_PlayVideo;
extern NSString * const ISMSNotification_RemoveMoviePlayer;

extern NSString * const ISMSNotification_ShowAlbumLoadingScreenOnMainWindow;
extern NSString * const ISMSNotification_ShowLoadingScreenOnMainWindow;
extern NSString * const ISMSNotification_HideLoadingScreen;

extern NSString * const ISMSNotification_ShowDeleteButton;
extern NSString * const ISMSNotification_HideDeleteButton;

extern NSString * const ISMSNotification_CachedSongDeleted;
