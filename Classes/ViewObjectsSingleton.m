//
//  ViewObjectsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ViewObjectsSingleton.h"

@implementation ViewObjectsSingleton

#pragma mark -
#pragma mark Class instance methods


- (void)enableCells
{
	self.isCellEnabled = YES;
}

- (void)hudWasHidden:(MBProgressHUD *)hud 
{
    // Remove HUD from screen when the HUD was hidden
    [self.HUD removeFromSuperview];
	self.HUD = nil;
}

- (void)showLoadingScreenOnMainWindowNotification:(NSNotification *)notification
{
    [self showLoadingScreenOnMainWindowWithMessage:notification.userInfo[@"message"]];
}

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message
{	
	[self showLoadingScreen:appDelegateS.window withMessage:message];
}

- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message
{
	if (self.isLoadingScreenShowing)
    {
        self.HUD.labelText = message ? message : self.HUD.labelText;
		return;
    }
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:view];
	[appDelegateS.window addSubview:self.HUD];
	self.HUD.delegate = self;
	self.HUD.labelText = message ? message : @"Loading";
	[self.HUD show:YES];
}

- (void)showAlbumLoadingScreenOnMainWindowNotification:(NSNotification *)notification
{
    [self showAlbumLoadingScreenOnMainWindowWithSender:notification.userInfo[@"sender"]];
}

- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender
{
    [self showAlbumLoadingScreen:appDelegateS.window sender:sender];
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender
{	
	if (self.isLoadingScreenShowing)
		return;
	
	self.isLoadingScreenShowing = YES;
	
	self.HUD = [[MBProgressHUD alloc] initWithView:appDelegateS.window];
	self.HUD.userInteractionEnabled = YES;
	
	// TODO: verify on iPad
	UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
	cancelButton.bounds = CGRectMake(0, 0, 1024, 1024);
	cancelButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[cancelButton addTarget:sender action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
	[self.HUD addSubview:cancelButton];
	
	[appDelegateS.window addSubview:self.HUD];
	self.HUD.delegate = self;
	self.HUD.labelText = @"Loading";
	self.HUD.detailsLabelText = @"tap to cancel";
	[self.HUD show:YES];
}
	
- (void)hideLoadingScreen
{
	if (!self.isLoadingScreenShowing)
		return;
	
	self.isLoadingScreenShowing = NO;
	
	[self.HUD hide:YES];
}

- (UIColor *)currentDarkColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return self.darkRed;
		case 1:
			return self.darkYellow;
		case 2:
			return self.darkGreen;
		case 3:
			return self.darkBlue;
		default:
			return self.darkNormal;
	}
	
	return self.darkNormal;
}

- (UIColor *) currentLightColor
{
	//switch ([[appDelegateS.settingsDictionary objectForKey:@"cacheSongCellColorSetting"] intValue])
	switch(settingsS.cachedSongCellColorType)
	{
		case 0:
			return self.lightRed;
		case 1:
			return self.lightYellow;
		case 2:
			return self.lightGreen;
		case 3:
			return self.lightBlue;
		default:
			return self.lightNormal;
	}
	
	return self.lightNormal;
}

#pragma mark Tab Saving

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (settingsS.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	if (settingsS.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	if (settingsS.isOfflineMode == NO)
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed
{
    NSUInteger count = tabBarController.viewControllers.count;
    NSMutableArray *savedTabsOrderArray = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++)
	{
        [savedTabsOrderArray addObject:@([[[tabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag])];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:savedTabsOrderArray] forKey:@"mainTabBarTabsOrder"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)orderMainTabBarController
{
	appDelegateS.currentTabBarController = appDelegateS.mainTabBarController;
	appDelegateS.mainTabBarController.delegate = self;
	
	NSArray *savedTabsOrderArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"mainTabBarTabsOrder"];
	
	// If this is an old device, remove Albums and Songs tabs
	//if (![[appDelegateS.settingsDictionary objectForKey:@"enableSongsTabSetting"] isEqualToString:@"YES"]) 
	if (!settingsS.isSongsTabEnabled)
	{
		//DLog(@"isSongsTabEnabled: %i", settingsS.isSongsTabEnabled);
		NSMutableArray *tabs = [[NSMutableArray alloc] init];
		for (UIViewController *controller in appDelegateS.mainTabBarController.viewControllers)
		{
			if (controller.tabBarItem.tag != 1 && controller.tabBarItem.tag != 2 && controller.tabBarItem.tag != 6)
			{
				[tabs addObject:controller];
			}
		}
		appDelegateS.mainTabBarController.viewControllers = tabs;
		
		tabs = [[NSMutableArray alloc] init];
		for (NSNumber *tag in savedTabsOrderArray)
		{
			if ([tag intValue] != 1 && [tag intValue] != 2 && [tag intValue] != 6)
			{
				[tabs addObject:tag];
			}
		}
		savedTabsOrderArray = tabs;
	}
	
	NSUInteger count = appDelegateS.mainTabBarController.viewControllers.count;
	//DLog(@"savedTabsOrderArray: %@", savedTabsOrderArray);
	if (savedTabsOrderArray.count == count) 
	{
		BOOL needsReordering = NO;
		
		NSMutableDictionary *tabsOrderDictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (int i = 0; i < count; i ++) 
		{
			NSNumber *tag = @([[[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag]);
			[tabsOrderDictionary setObject:@(i) forKey:[tag stringValue]];
			
			if (!needsReordering && ![(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] isEqualToNumber:tag]) 
			{
				needsReordering = YES;
			}
		}
		
		if (needsReordering) 
		{
			NSMutableArray *tabsViewControllers = [[NSMutableArray alloc] initWithCapacity:count];
			for (int i = 0; i < count; i ++) 
			{
				[tabsViewControllers addObject:[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:[(NSNumber *)[tabsOrderDictionary objectForKey:[(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] stringValue]] intValue]]];
			}
			
			appDelegateS.mainTabBarController.viewControllers = [NSArray arrayWithArray:tabsViewControllers];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"]) 
	{
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"] == 2147483647) 
		{
			appDelegateS.mainTabBarController.selectedViewController = appDelegateS.mainTabBarController.moreNavigationController;
		}
		else 
		{
			appDelegateS.mainTabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"];
		}
	}
	
	appDelegateS.mainTabBarController.moreNavigationController.delegate = self;
}

- (UIView *)createCellBackground:(NSUInteger)row
{
    if (IS_IOS7())
    {
        return [[UIView alloc] init];
    }
    else
    {
        UIView *backgroundView = [[UIView alloc] init];
        backgroundView.backgroundColor = self.lightNormal;
        return backgroundView;
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
	_lightRed = [UIColor colorWithRed:255/255.0 green:146/255.0 blue:115/255.0 alpha:1];
	_darkRed = [UIColor colorWithRed:226/255.0 green:0/255.0 blue:0/255.0 alpha:1];
	
	_lightYellow = [UIColor colorWithRed:255/255.0 green:233/255.0 blue:115/255.0 alpha:1];
	_darkYellow = [UIColor colorWithRed:255/255.0 green:215/255.0 blue:0/255.0 alpha:1];
	
	_lightGreen = [UIColor colorWithRed:169/255.0 green:241/255.0 blue:108/255.0 alpha:1];
	_darkGreen = [UIColor colorWithRed:103/255.0 green:227/255.0 blue:0/255.0 alpha:1];
	
	_lightBlue = [UIColor colorWithRed:87/255.0 green:198/255.0 blue:255/255.0 alpha:1];
	_darkBlue = [UIColor colorWithRed:28/255.0 green:163/255.0 blue:255/255.0 alpha:1];
	
	_lightNormal = [UIColor whiteColor];
	_darkNormal = ISMSHeaderColor;

	_windowColor = [UIColor colorWithWhite:.3 alpha:1];
	_jukeboxColor = [UIColor colorWithRed:140.0/255.0 green:0.0 blue:0.0 alpha:1.0];
	
	_isCellEnabled = YES;
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showAlbumLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(hideLoadingScreen) name:ISMSNotification_HideLoadingScreen object:nil];
}

+ (id)sharedInstance
{
    static ViewObjectsSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
