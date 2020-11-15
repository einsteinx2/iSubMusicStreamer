//
//  ViewObjectsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_ViewObjectsSingleton_h
#define iSub_ViewObjectsSingleton_h

#define viewObjectsS ((ViewObjectsSingleton *)[ViewObjectsSingleton sharedInstance])

#import "MBProgressHUD.h"

@class FoldersViewController, ISMSArtist, LoadingScreen, ISMSAlbum, AlbumViewController, ISMSServer;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ViewObjects)
@interface ViewObjectsSingleton : NSObject <UITabBarControllerDelegate, UINavigationControllerDelegate, MBProgressHUDDelegate>

@property (nullable, strong) MBProgressHUD *HUD;

// Artists page objects
//
@property BOOL isArtistsLoading;

// Playlists view objects
//
@property BOOL isLocalPlaylist;

// Settings page objects
//
@property (nullable, strong) ISMSServer *serverToEdit;

// Chat page objects
//
@property (strong) NSMutableArray *chatMessages;

// New Stuff
@property (strong) NSTimer *cellEnabledTimer;
@property (strong) NSMutableArray *multiDeleteList;
@property BOOL isOnlineModeAlertShowing;

// Cell colors
//
@property (strong) UIColor *lightRed;
@property (strong) UIColor *darkRed;
@property (strong) UIColor *lightYellow;
@property (strong) UIColor *darkYellow;
@property (strong) UIColor *lightGreen;
@property (strong) UIColor *darkGreen;
@property (strong) UIColor *lightBlue;
@property (strong) UIColor *darkBlue;
@property (strong) UIColor *lightNormal;
@property (strong) UIColor *darkNormal;
@property (strong) UIColor *windowColor;
@property (strong) UIColor *jukeboxColor;

@property BOOL isNoNetworkAlertShowing;

@property BOOL isLoadingScreenShowing;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)orderMainTabBarController;

- (void)showLoadingScreenOnMainWindowWithMessage:(nullable NSString *)message;
- (void)showLoadingScreen:(UIView *)view withMessage:(nullable NSString *)message;
- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;
- (UIColor *)currentLightColor;
- (UIColor *)currentDarkColor;

@end

NS_ASSUME_NONNULL_END

#endif
