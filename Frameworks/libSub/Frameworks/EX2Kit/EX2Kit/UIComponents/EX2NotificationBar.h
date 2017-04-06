//
//  EX2NotificationBar.h
//
//  Created by Ben Baron on 4/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

// If you use a UITabBarController, switch to using EX2TabBarController,
// and if you're using UINavigationController, use EX2NavigationController.
// There are a bunch of dirty hacks in here to support the UIKit classes,
// but they don't work nearly as well and not every edge case is covered.

#import <UIKit/UIKit.h>

extern NSString * const EX2NotificationBarWillShow;
extern NSString * const EX2NotificationBarWillHide;
extern NSString * const EX2NotificationBarDidShow;
extern NSString * const EX2NotificationBarDidHide;

typedef enum 
{
	EX2NotificationBarPositionTop,
	EX2NotificationBarPositionBottom
} 
EX2NotificationBarPosition;

@interface EX2NotificationBar : UIViewController

// View to place notification bar content. May add any custom subviews, etc. 
// Think of like UITableViewCell contentView.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
@property (nonatomic, readwrite, retain) IBOutlet UIView *notificationBarContent;
#else
@property (nonatomic, readwrite, retain) IBOutlet UIView *notificationBarContent;
#endif

// The notification bar area. Contains the content view and shadows. Always add
// subviews to the content view, NOT to this view, or they will be placed
// above the shadows unless you specifically move them backwards in the hierarchy
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
@property (nonatomic, readwrite, retain) IBOutlet UIView *notificationBar;
#else
@property (nonatomic, readwrite, retain) IBOutlet UIView *notificationBar;
#endif

// The view that contains the main view. This is where you would add your UITabBarController,
// UINavigationController, etc.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
@property (nonatomic, readwrite, retain) IBOutlet UIView *mainViewHolder;
#else
@property (nonatomic, readwrite, retain) IBOutlet UIView *mainViewHolder;
#endif

// YES when the notificationBar is visible
@property (nonatomic, readwrite) BOOL isNotificationBarShowing;

// YES when the notificationBar is currently transitioning
@property (nonatomic, readwrite) BOOL isNotificationBarAnimating;

// This can be changed during runtime, but only when isNotificationBarShowing == NO
@property (nonatomic) EX2NotificationBarPosition notificationBarPosition;

// This is a reference to whatever controller manages the view you placed in mainViewHolder
@property (nonatomic, strong) IBOutlet UIViewController *mainViewController;

// The height of the content area when shown
@property CGFloat notificationBarHeight;

// Adjust sizes for iOS 7 status bar
@property (nonatomic) BOOL isEnableiOS7Fix;

- (id)initWithPosition:(EX2NotificationBarPosition)position;

- (id)initWithPosition:(EX2NotificationBarPosition)position mainViewController:(UIViewController *)mainViewController;


// Show the notificationBar temporarily, then automatically dismiss
- (void)showAndHideForDuration:(NSTimeInterval)duration;
- (void)showAndHide;

// Show the notificationBar indefinitely
- (void)show;
- (void)show:(void (^)(void))completionBlock;

// Hide the notificationBar
- (void)hide;
- (void)hide:(void (^)(void))completionBlock;

@end
