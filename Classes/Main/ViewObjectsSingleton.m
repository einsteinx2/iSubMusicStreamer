//
//  ViewObjectsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
#import "MBProgressHUD.h"
#import "CustomUITabBarController.h"
#import "CustomUINavigationController.h"

#define HUD_GRACE_TIME 0.5

@interface ViewObjectsSingleton() <MBProgressHUDDelegate>
@property (nullable, strong) MBProgressHUD *HUD;
@property BOOL isLoadingScreenShowing;
@end

@implementation ViewObjectsSingleton

- (void)hudWasHidden:(MBProgressHUD *)hud  {
    // Remove HUD from screen when the HUD was hidden
    [self.HUD removeFromSuperview];
	self.HUD = nil;
}

- (void)showLoadingScreenOnMainWindowNotification:(NSNotification *)notification {
    [self showLoadingScreenOnMainWindowWithMessage:notification.userInfo[@"message"]];
}

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message {
	[self showLoadingScreen:appDelegateS.window withMessage:message];
}

- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message {
	if (self.isLoadingScreenShowing) {
        self.HUD.label.text = message ? message : self.HUD.label.text;
		return;
    }
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:view];
    self.HUD.graceTime = HUD_GRACE_TIME;
	[appDelegateS.window addSubview:self.HUD];
	self.HUD.delegate = self;
    self.HUD.label.text = message ? message : @"Loading";
    [self.HUD showAnimated:YES];
}

- (void)showAlbumLoadingScreenOnMainWindowNotification:(NSNotification *)notification {
    [self showAlbumLoadingScreenOnMainWindowWithSender:notification.userInfo[@"sender"]];
}

- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender {
    [self showAlbumLoadingScreen:appDelegateS.window sender:sender];
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender {
	if (self.isLoadingScreenShowing) return;
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:appDelegateS.window];
	self.HUD.userInteractionEnabled = YES;
    self.HUD.graceTime = HUD_GRACE_TIME;
	
	// TODO: verify on iPad
	UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([sender respondsToSelector:@selector(cancelLoad)]) {
        [cancelButton addTarget:sender action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
    }
#pragma clang diagnostic pop
    [self.HUD.bezelView addSubview:cancelButton];
    [NSLayoutConstraint activateConstraints:@[
        [cancelButton.leadingAnchor constraintEqualToAnchor:self.HUD.bezelView.leadingAnchor],
        [cancelButton.trailingAnchor constraintEqualToAnchor:self.HUD.bezelView.trailingAnchor],
        [cancelButton.topAnchor constraintEqualToAnchor:self.HUD.bezelView.topAnchor],
        [cancelButton.bottomAnchor constraintEqualToAnchor:self.HUD.bezelView.bottomAnchor]
    ]];
	
	[appDelegateS.window addSubview:self.HUD];
	self.HUD.delegate = self;
    self.HUD.label.text = @"Loading";
    self.HUD.detailsLabel.text = @"tap to cancel";
    [self.HUD showAnimated:YES];
}
	
- (void)hideLoadingScreen {
	if (!self.isLoadingScreenShowing) return;
	self.isLoadingScreenShowing = NO;
    [self.HUD hideAnimated:YES];
}

- (UIColor *)currentDarkColor {
	switch(settingsS.cachedSongCellColorType) {
		case 0: return self.darkRed;
		case 1: return self.darkYellow;
		case 2: return self.darkGreen;
		case 3: return self.darkBlue;
		default: return self.darkBlue;
	}
}

#pragma mark Tab Saving

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Prevent view controllers from going under the navigation bar
    viewController.edgesForExtendedLayout = UIRectEdgeNone;
    
    // Remember selected tab
    if (!settingsS.isOfflineMode) {
        [[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Remember selected tab
    if (!settingsS.isOfflineMode) {
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    // Remember selected tab
    if (!settingsS.isOfflineMode) {
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
    NSUInteger count = tabBarController.viewControllers.count;
    NSMutableArray *savedTabsOrder = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++) {
        [savedTabsOrder addObject:@([[[tabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag])];
    }
    [NSUserDefaults.standardUserDefaults setObject:savedTabsOrder forKey:@"mainTabBarTabsOrder"];
	[NSUserDefaults.standardUserDefaults synchronize];
}

- (void)setup {
	_darkRed = [UIColor colorWithRed:226/255.0 green:0/255.0 blue:0/255.0 alpha:1];
	_darkYellow = [UIColor colorWithRed:255/255.0 green:215/255.0 blue:0/255.0 alpha:1];
	_darkGreen = [UIColor colorWithRed:103/255.0 green:227/255.0 blue:0/255.0 alpha:1];
	_darkBlue = [UIColor colorWithRed:28/255.0 green:163/255.0 blue:255/255.0 alpha:1];
	
	_windowColor = [UIColor colorWithWhite:.3 alpha:1];
	_jukeboxColor = [UIColor colorWithRed:140.0/255.0 green:0.0 blue:0.0 alpha:1.0];
		
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showAlbumLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(hideLoadingScreen) name:ISMSNotification_HideLoadingScreen object:nil];
}

+ (instancetype)sharedInstance {
    static ViewObjectsSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
