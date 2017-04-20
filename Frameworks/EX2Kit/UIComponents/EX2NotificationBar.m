//
//  EX2NotificationBar.m
//
//  Created by Ben Baron on 4/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIView+Tools.h"
#import "EX2NotificationBar.h"
#import "EX2Macros.h"
#import "EX2Kit.h"

#define DEFAULT_HIDE_DURATION 5.0
#define ANIMATE_DUR 0.3
#define DEFAULT_BAR_HEIGHT 30.
#define SMALL_STATUS_HEIGHT 20.
#define LARGE_STATUS_HEIGHT 40.
#define ACTUAL_STATUS_HEIGHT [[UIApplication sharedApplication] statusBarFrame].size.height

#define TopY (self.isEnableiOS7Fix && SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7") ? 20. : 0.)

NSString * const EX2NotificationBarWillShow = @"EX2NotificationBarWillShow";
NSString * const EX2NotificationBarWillHide = @"EX2NotificationBarWillHide";
NSString * const EX2NotificationBarDidShow = @"EX2NotificationBarDidShow";
NSString * const EX2NotificationBarDidHide = @"EX2NotificationBarDidHide";

@interface EX2NotificationBar()
@property (nonatomic) BOOL wasStatusBarTallOnStart;
@property (nonatomic) BOOL changedTabSinceTallHeight;
@property (nonatomic) BOOL hasViewWillAppearRan;
@end

@implementation EX2NotificationBar
@synthesize mainViewController=_mainViewController;
@synthesize notificationBarPosition=_notificationBarPosition;
@synthesize notificationBarContent=_notificationBarContent;
@synthesize mainViewHolder=_mainViewHolder;
@synthesize notificationBar=_notificationBar;

#pragma mark - Life Cycle

- (void)setup
{
	_notificationBarHeight = DEFAULT_BAR_HEIGHT;
	_notificationBarPosition = EX2NotificationBarPositionTop;
}

- (id)initWithPosition:(EX2NotificationBarPosition)position
{
	if ((self = [super initWithNibName:@"EX2NotificationBar" bundle:[EX2Kit resourceBundle]]))
	{
		[self setup];
		_notificationBarPosition = position;
	}
	return self;
}

- (id)initWithPosition:(EX2NotificationBarPosition)thePosition mainViewController:(UIViewController *)mainViewController
{
    if ((self = [super initWithNibName:@"EX2NotificationBar" bundle:[EX2Kit resourceBundle]]))
	{
		[self setup];
		_notificationBarPosition = thePosition;
        _mainViewController = mainViewController;
	}
	return self;
}



- (id)init
{
	return [self initWithPosition:EX2NotificationBarPositionTop];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self init];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		[self setup];
	}
	return self;
}

- (void)dealloc
{
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    	
	// Setup the main view controller if it was done before the XIB loaded
	self.mainViewController = self.mainViewController;
    
    // Register for status bar frame changes
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(statusBarDidChange:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.mainViewController viewWillAppear:animated];
	}
    
    // Fix for iOS 7 status bar
    if (self.isEnableiOS7Fix && IS_IOS7())
    {
        if (self.mainViewHolder.y == 0.)
        {
            self.mainViewHolder.y = 20.;
            self.mainViewHolder.height -= 20.;
            
            self.notificationBar.y = 20.;
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.mainViewController viewWillDisappear:animated];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	   
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.mainViewController viewDidAppear:animated];
	}
    
    // Fix for modal view controller dismissal positioning
    if ([self.mainViewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tabController = (UITabBarController *)self.mainViewController;
        if ([tabController.selectedViewController isKindOfClass:[UINavigationController class]])
        {
            UINavigationController *navController = (UINavigationController *)tabController.selectedViewController;
            if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT)
            {
                [UIView animateWithDuration:.2 animations:^{
                    
                    CGFloat heightChange = self.isNotificationBarShowing ? LARGE_STATUS_HEIGHT : SMALL_STATUS_HEIGHT;
                    
                    if (self.hasViewWillAppearRan)
                    {
                        CGRect theFrame = CGRectMake(0., heightChange, navController.visibleViewController.view.width, navController.visibleViewController.view.height - heightChange);
                        navController.visibleViewController.view.frame = theFrame;
                    }
                    
                    if (!self.wasStatusBarTallOnStart || self.hasViewWillAppearRan)
                        navController.navigationBar.y += heightChange;
                }];
            }
        }
    }
    
    self.hasViewWillAppearRan = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.mainViewController viewDidDisappear:animated];
	}
}

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    switch([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationLandscapeLeft:
            orientation = UIInterfaceOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = UIInterfaceOrientationLandscapeRight;
            break;
        case UIDeviceOrientationPortrait:
            orientation = UIInterfaceOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = UIInterfaceOrientationPortraitUpsideDown;
            break;
        default:
            orientation = UIInterfaceOrientationPortrait;
    }
    
    return [self shouldAutorotateToInterfaceOrientation:orientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	// Don't allow rotating while the notification bar is animating
	if (self.isNotificationBarAnimating)
	{
		return inOrientation == [UIApplication sharedApplication].statusBarOrientation;
	}

	// Otherwise ask the main view controller
	return [self.mainViewController shouldAutorotateToInterfaceOrientation:inOrientation];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[self.mainViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
		
	if ([self.mainViewController isKindOfClass:[UITabBarController class]])
	{
		UITabBarController *tabController = (UITabBarController *)self.mainViewController;
		if ([tabController.selectedViewController isKindOfClass:[UINavigationController class]])
		{
			// Must resize the navigation bar manually because it will only happen automatically when 
			// it's the main window's root view controller
			UINavigationController *navController = (UINavigationController *)tabController.selectedViewController;
			navController.navigationBar.height = UIInterfaceOrientationIsPortrait(toInterfaceOrientation) ? 44. : 32.;
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	[self.mainViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	if (self.isNotificationBarShowing)
	{
		if ([self.mainViewController isKindOfClass:[UITabBarController class]])
		{
			UITabBarController *tabController = (UITabBarController *)self.mainViewController;
			if ([tabController.selectedViewController isKindOfClass:[UINavigationController class]])
			{
				// Must shift down the navigation controller after switching tabs
				UINavigationController *navController = (UINavigationController *)tabController.selectedViewController;
				navController.view.y = ACTUAL_STATUS_HEIGHT;
			}
		}
	}
}

#pragma mark - Properties

- (EX2NotificationBarPosition)notificationBarPosition
{
	return _notificationBarPosition;
}

- (void)setNotificationBarPosition:(EX2NotificationBarPosition)notificationBarPosition
{
	if (!self.isNotificationBarShowing)
	{
		_notificationBarPosition = notificationBarPosition;
	}
}

- (UIViewController *)mainViewController
{
	return _mainViewController;
}

- (void)setMainViewController:(UIViewController *)theMainViewController
{
	// Remove the old controller's view, if there is one
	for (UIView *subview in _mainViewHolder.subviews)
	{
        [subview.viewController removeFromParentContainerViewController];
	}
        
	// Set the new controller
	_mainViewController = theMainViewController;
    
    // Make sure it's the right size
    _mainViewController.view.frame = self.mainViewHolder.bounds;
	
	// Add the new controller's view
    [self insertAsChildViewController:_mainViewController];
	
	// Handle UITabBarController weirdness
	if ([_mainViewController isKindOfClass:[UITabBarController class]])
	{
		_mainViewController.view.y = -ACTUAL_STATUS_HEIGHT;
	}
    
    if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT)
        self.wasStatusBarTallOnStart = YES;
    
    // Add tab change observation
    if ([_mainViewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tabController = (UITabBarController *)_mainViewController;
        @try
        {
            [tabController removeObserver:self forKeyPath:@"selectedViewController"];
        }
        @catch (id anException)
        {
            // Ignore this
        }
        [tabController addObserver:self forKeyPath:@"selectedViewController" options:NSKeyValueObservingOptionOld context:NULL];
    }
}

#pragma mark - Methods

- (void)showAndHideForDuration:(NSTimeInterval)duration
{
	[self show];
	[self performSelector:@selector(hide) withObject:nil afterDelay:duration];
}

- (void)showAndHide
{
	[self showAndHideForDuration:DEFAULT_HIDE_DURATION];
}

- (void)show
{
	[self show:NULL];
}

- (void)show:(void (^)(void))completionBlock
{
	if (self.isNotificationBarShowing)
	{
        // If already showing, do nothing
        return;
    }
    _isNotificationBarShowing = YES;
    
    if (!self.isNotificationBarAnimating)
    {
        // If currently animating, cancel all animations
        [self.notificationBar.layer removeAllAnimations];
        [self.mainViewHolder.layer removeAllAnimations];
    }
    _isNotificationBarAnimating = YES;
    
	if (completionBlock != NULL)
	{
		completionBlock = [completionBlock copy];
	}
    	
	if (self.notificationBarPosition == EX2NotificationBarPositionTop)
	{
		self.notificationBar.height = 0;
	}
	else if (self.notificationBarPosition == EX2NotificationBarPositionBottom)
	{
		//self.view.y = self.view.superview.height - self.view.height + 20.;
		//self.view.width = self.view.superview.width;
		//self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		
		self.notificationBar.y = TopY + (self.view.height - self.notificationBar.height);
	}
    	
	void (^animations)(void) = ^(void)
	{
		if (self.notificationBarPosition == EX2NotificationBarPositionTop)
		{	
			self.notificationBar.height = self.notificationBarHeight;
			self.mainViewHolder.frame = CGRectMake(self.mainViewHolder.x,
                                                   self.mainViewHolder.y + self.notificationBarHeight,
                                                   self.mainViewHolder.width,
                                                   self.mainViewHolder.height - self.notificationBarHeight);
            
            if (self.mainViewHolder.y < TopY)
                self.mainViewHolder.y = TopY;
		}
		else if (self.notificationBarPosition == EX2NotificationBarPositionBottom)
		{
			self.mainViewHolder.height -= self.notificationBar.height;
		}
	};
	
	void (^completion)(BOOL) = ^(BOOL finished)
	{
        if (finished)
        {            
            [[NSNotificationCenter defaultCenter] postNotificationName:EX2NotificationBarDidShow object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:nil];
            
            if (completionBlock != NULL)
            {
                completionBlock();
            }
        }
        
        _isNotificationBarAnimating = NO;
	};
	
	[[NSNotificationCenter defaultCenter] postNotificationName:EX2NotificationBarWillShow object:nil];
	
	[UIView animateWithDuration:ANIMATE_DUR 
						  delay:0.0 
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:animations
					 completion:completion];
}

- (void)hide
{
	[self hide:NULL];
}

- (void)hide:(void (^)(void))completionBlock
{
	if (!self.isNotificationBarShowing)
	{
        // If already showing, do nothing
        return;
    }
    _isNotificationBarShowing = NO;
    
    if (!self.isNotificationBarAnimating)
    {
        // If currently animating, cancel all animations
        [self.notificationBar.layer removeAllAnimations];
        [self.mainViewHolder.layer removeAllAnimations];
    }
    _isNotificationBarAnimating = YES;
		
	if (completionBlock != NULL)
	{
		completionBlock = [completionBlock copy];
	}
	
	void (^animations)(void) = ^(void)
	{
		if (self.notificationBarPosition == EX2NotificationBarPositionTop)
		{
			self.notificationBar.height = 0.;
			self.mainViewHolder.frame = CGRectMake(self.mainViewHolder.x, 
                                                   self.mainViewHolder.y - self.notificationBarHeight, 
                                                   self.mainViewHolder.width, 
                                                   self.mainViewHolder.height + self.notificationBarHeight);
            
            if (self.mainViewHolder.y < 0.) self.mainViewHolder.y = 0.;
		}
		else if (self.notificationBarPosition == EX2NotificationBarPositionBottom)
		{
			self.mainViewHolder.height += self.notificationBar.height; 
			//UIView *topView = appDelegateS.mainTabBarController.selectedViewController.view;
			//topView.height += self.notificationBar.height; 
		}
	};
	
	void (^completion)(BOOL) = ^(BOOL finished) 
	{
        if (finished)
        {            
            [[NSNotificationCenter defaultCenter] postNotificationName:EX2NotificationBarDidHide object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:nil];
            
            if (completionBlock != NULL)
            {
                completionBlock();
            }
        }
        
        _isNotificationBarAnimating = NO;
	};
	
	[[NSNotificationCenter defaultCenter] postNotificationName:EX2NotificationBarWillHide object:nil];
	
	[UIView animateWithDuration:ANIMATE_DUR 
						  delay:0. 
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:animations 
					 completion:completion];
}

// Handle status bar height changes
- (void)statusBarDidChange:(NSNotification *)notification
{    
    if ([self.mainViewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tabController = (UITabBarController *)self.mainViewController;
        if ([tabController.selectedViewController isKindOfClass:[UINavigationController class]])
        {            
            // Must shift down the navigation controller after switching tabs
            UINavigationController *navController = (UINavigationController *)tabController.selectedViewController;
            
            if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT)
            {
                if (self.wasStatusBarTallOnStart)
                {
                    [UIView animateWithDuration:.2 animations:^{
                        
                        if (self.isNotificationBarShowing)
                        {
                            CGRect theFrame = CGRectMake(0., LARGE_STATUS_HEIGHT, navController.visibleViewController.view.width, navController.visibleViewController.view.height - LARGE_STATUS_HEIGHT);
                            navController.visibleViewController.view.frame = theFrame;
                        }
                        
                        navController.navigationBar.y = LARGE_STATUS_HEIGHT;
                    }];
                }
                else if (self.isNotificationBarShowing)
                {
                    CGFloat heightChange = self.changedTabSinceTallHeight ? LARGE_STATUS_HEIGHT : SMALL_STATUS_HEIGHT;
                    
                    [UIView animateWithDuration:.2 animations:^{
                        CGRect theFrame = CGRectMake(0., heightChange, navController.view.width, navController.view.height - heightChange);
                        navController.view.frame = theFrame;
                    }];
                }
                else
                {
                    CGFloat heightChange = SMALL_STATUS_HEIGHT;//self.changedTabSinceTallHeight ? LARGE_STATUS_HEIGHT : SMALL_STATUS_HEIGHT;
                    
                    [UIView animateWithDuration:.2 animations:^{
                        CGRect theFrame = CGRectMake(0., heightChange, navController.visibleViewController.view.width, navController.visibleViewController.view.height - heightChange);
                        navController.visibleViewController.view.frame = theFrame;
                        
                        navController.navigationBar.y = SMALL_STATUS_HEIGHT;
                    }];
                }
            }
            else
            {
                if (self.wasStatusBarTallOnStart)
                {
                    [UIView animateWithDuration:.2 animations:^{
                        //navController.navigationBar.y -= LARGE_STATUS_HEIGHT;
                        //navController.view.y += LARGE_STATUS_HEIGHT;
                        
                        navController.navigationBar.y = 0.;
                        
                        CGRect theFrame = CGRectMake(0., LARGE_STATUS_HEIGHT, navController.view.width, navController.view.height - LARGE_STATUS_HEIGHT);
                        navController.view.frame = theFrame;
                    }];
                }
                else if (self.isNotificationBarShowing)
                {
                    [UIView animateWithDuration:.2 animations:^{
                        CGRect theFrame = CGRectMake(0., SMALL_STATUS_HEIGHT, navController.view.width, navController.view.height - SMALL_STATUS_HEIGHT);
                        navController.view.frame = theFrame;
                    }];
                }
                else if (self.changedTabSinceTallHeight)
                {
                    [UIView animateWithDuration:.2 animations:^{
                        navController.navigationBar.y += SMALL_STATUS_HEIGHT;
                    }];
                }
            }
        }
    }
}

// Handle tab bar changes
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.changedTabSinceTallHeight = ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT;

    if ([keyPath isEqualToString:@"selectedViewController"])
    {
        if ([object isKindOfClass:[UITabBarController class]])
        {
            id oldValue = change[NSKeyValueChangeOldKey];
            UITabBarController *tabController = (UITabBarController *)object;
            
            if (oldValue != tabController.selectedViewController)
            {
                // Only if the tab actually changed
                if ([tabController.selectedViewController isKindOfClass:[UINavigationController class]])
                {
                    // Must shift down the navigation controller after switching tabs
                    UINavigationController *navController = (UINavigationController *)tabController.selectedViewController;
                    
                    if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT || self.isNotificationBarShowing)
                    {
                        CGFloat changeHeight = SMALL_STATUS_HEIGHT;
                        if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT)
                            changeHeight = self.wasStatusBarTallOnStart ? LARGE_STATUS_HEIGHT : SMALL_STATUS_HEIGHT;
                        else if (ACTUAL_STATUS_HEIGHT < LARGE_STATUS_HEIGHT && self.wasStatusBarTallOnStart)
                            changeHeight = LARGE_STATUS_HEIGHT;
                        
                        if (ACTUAL_STATUS_HEIGHT > SMALL_STATUS_HEIGHT || self.isNotificationBarShowing)
                        {
                            if (self.wasStatusBarTallOnStart && !self.isNotificationBarShowing)
                            {
                                return;
                            }
                            
                            navController.view.y += changeHeight;
                            
                            CGRect theFrame = CGRectMake(0., 0, navController.visibleViewController.view.width, navController.visibleViewController.view.height - SMALL_STATUS_HEIGHT);
                            navController.visibleViewController.view.frame = theFrame;
                        }
                    }
                    else if (ACTUAL_STATUS_HEIGHT < LARGE_STATUS_HEIGHT && self.wasStatusBarTallOnStart)
                    {
                        navController.view.y = LARGE_STATUS_HEIGHT;
                    }
                }
            }
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
