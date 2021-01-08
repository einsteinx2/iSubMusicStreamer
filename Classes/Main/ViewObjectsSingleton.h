//
//  ViewObjectsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_ViewObjectsSingleton_h
#define iSub_ViewObjectsSingleton_h

#import <UIKit/UIKit.h>

#define viewObjectsS ((ViewObjectsSingleton *)[ViewObjectsSingleton sharedInstance])

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ViewObjects)
@interface ViewObjectsSingleton : NSObject <UITabBarControllerDelegate, UINavigationControllerDelegate>

// Artists page objects
//
@property BOOL isArtistsLoading;

// Cell colors
//
@property (strong) UIColor *darkRed;
@property (strong) UIColor *darkYellow;
@property (strong) UIColor *darkGreen;
@property (strong) UIColor *darkBlue;
@property (strong) UIColor *windowColor;
@property (strong) UIColor *jukeboxColor;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)orderMainTabBarController;

- (void)showLoadingScreenOnMainWindowWithMessage:(nullable NSString *)message;
- (void)showLoadingScreen:(UIView *)view withMessage:(nullable NSString *)message;
- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;
- (UIColor *)currentDarkColor;

@end

NS_ASSUME_NONNULL_END

#endif
