//
//  Common-Bridging-Header.h
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

/*
 * Import Objective-C headers here to be exposed to Swift in all build targets
 */

#ifndef Common_Bridging_Header_h
#define Common_Bridging_Header_h

#import "Defines.h"
#import "ObjcExceptionCatcher.h"

/*
 * User Interface Components
 */

// View Controllers
#import "CustomUINavigationController.h"
#import "ChatViewController.h"
#import "SearchSongsViewController.h"
#import "HomeAlbumViewController.h"
#import "CurrentPlaylistViewController.h"
#import "EqualizerViewController.h"
#import "ServerListViewController.h"
#import "CacheViewController.h"
#import "PlaylistsViewController.h"
#import "BookmarksViewController.h"
#import "FoldersViewController.h"
#import "PlayingViewController.h"

// Views
#import "CellCachedIndicatorView.h"

/*
 * Data Models
 */

// Loaders
#import "ISMSErrorDomain.h"

// DAOs
#import "ISMSBookmarkDAO.h"

// Parsers
#import "RXMLElement.h"

// Utils
#import "EX2Dispatch.h"

/*
 * Extensions
 */

#import "UIViewController+PushViewControllerCustom.h"
#import "NSString+time.h"
#import "NSMutableURLRequest+SUS.h"
#import "UIApplication+Helper.h"
#import "UIDevice+Info.h"
#import "NSNotificationCenter+MainThread.h"
#import "NSString+FileSize.h"
#import "NSString+Clean.h"
#import "NSError+ISMSError.h"
#import "NSString+MD5.h"

/*
 * Singletons
 */

#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "JukeboxSingleton.h"
#import "SavedSettings.h"
#import "AudioEngine.h"
#import "ISMSStreamManager.h"
#import "DatabaseSingleton.h"
#import "CacheSingleton.h"

/*
 * Frameworks
 */

#import "Flurry.h"
#import "OBSlider.h"
#import "FMDatabaseQueueAdditions.h"
#import "FMDatabaseAdditions.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"

#endif /* Common_Bridging_Header_h */
