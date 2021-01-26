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
#import "EqualizerViewController.h"
#import "BookmarksViewController.h"
#import "OptionsViewController.h"

// Views
#import "FolderDropdownControl.h"

/*
 * Data Models
 */

// Loaders
#import "ISMSErrorDomain.h"

// DAOs
#import "ISMSBookmarkDAO.h"

// Parsers
#import "RXMLElement.h"

/*
 * Extensions
 */

#import "NSString+time.h"
#import "UIDevice+Info.h"
#import "NSString+FileSize.h"
#import "NSError+ISMSError.h"
#import "GTMNSString+HTML.h"
#import "NSURL+SkipBackupAttribute.h"

/*
 * Singletons
 */

#import "SavedSettings.h"
#import "BassGaplessPlayer.h"

/*
 * Frameworks
 */

#import "Flurry.h"
#import "OBSlider.h"
#import "MBProgressHUD.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"
#import "Reachability.h"
#import "EX2NetworkIndicator.h"

#endif /* Common_Bridging_Header_h */
