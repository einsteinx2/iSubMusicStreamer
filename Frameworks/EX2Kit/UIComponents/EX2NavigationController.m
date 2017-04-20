//
//  EX2NavigationController.m
//  WOD
//
//  Created by Casey Marshall on 2/3/11.
//  Copyright 2011 Modal Domains. All rights reserved.
//
//  ---------------------------
//
//  Modified by Ben Baron for EX2Kit
//

#import "EX2NavigationController.h"
#import <objc/runtime.h>

@implementation UIViewController (EX2NavigationController)

// No adding instance properties in categories you say? Hogwash! Three cheers for associative references!
static void *key;
- (EX2NavigationController *)ex2NavigationController
{
    // Try to get the reference
    EX2NavigationController *navController = (EX2NavigationController *)objc_getAssociatedObject(self, &key);
    
    // This ensures that if this controller is inside another and so it's property
    // was not set directly, we'll still get the reference
    if (!navController && [self respondsToSelector:@selector(parentViewController)])
    {
        // Check it's parent controllers
        UIViewController *parent = self.parentViewController;
        while (parent)
        {
            navController = (EX2NavigationController *)objc_getAssociatedObject(parent, &key);
            if (navController)
                break;
            else
                parent = parent.parentViewController;
        }
    }
    
    return navController;
}
- (void)setEx2NavigationController:(EX2NavigationController *)ex2NavigationController
{
    objc_setAssociatedObject(self, &key, ex2NavigationController, OBJC_ASSOCIATION_ASSIGN);
}

@end

@interface EX2NavigationController()
@property (nonatomic) BOOL isAnimating;
@end

@implementation EX2NavigationController

#define AnimationDuration 0.3
#define AnimationCurve IS_IOS7() ? UIViewAnimationOptionCurveEaseOut : UIViewAnimationOptionCurveEaseInOut

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
		_viewControllers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        _viewControllers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)viewController
{
	if (self = [super init])
	{
        viewController.ex2NavigationController = self;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
        {
            [self addChildViewController:viewController];
        }
		
		if (viewController)
			_viewControllers = [[NSMutableArray alloc] initWithObjects:viewController, nil];
		else
			_viewControllers = [[NSMutableArray alloc] init];
    }
	return self;
}

- (void)dealloc
{
    [EX2Dispatch runInMainThreadAndWaitUntilDone:YES block:^{
        for (int i = _viewControllers.count - 1; i >= 0; i--)
        {
            UIViewController *controller = [_viewControllers objectAtIndex:i];
            controller.ex2NavigationController = nil;
            [_viewControllers removeObjectAtIndexSafe:i];
        }
    }];
}

// To allow easy overriding with custom navigation bar. Useful for skinning the nav bar in iOS 4
// (have a EX2NavivigationBar subclass return a custom UINavigationBar subclass from this method)
- (UINavigationBar *)createNavigationBar
{
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    navBar.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    return navBar;
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, 480)];
	self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    self.view.clipsToBounds = YES;
    
	self.navigationBar = [self createNavigationBar];
    
	self.contentView = [[UIView alloc ] initWithFrame:CGRectMake(0, self.navigationBar.bottom, self.view.width, self.view.height - self.navigationBar.height)];
    self.contentView.clipsToBounds = YES;
	self.contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    
    // Handle the case where we set the isNavigationBarHidden property before the view loads
    if (self.isNavigationBarHidden)
    {
        self.navigationBar.bottom = 0.;
        self.contentView.frame = self.view.bounds;
    }
    
    [self.view addSubview:self.contentView];
	[self.view addSubview:self.navigationBar];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        [[self.viewControllers firstObjectSafe] didMoveToParentViewController:self];
    }
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
	if (self.viewControllers.count > 0)
	{
		UIViewController *current = self.viewControllers.lastObject;
		
		if ([self.delegate respondsToSelector:@selector(ex2NavigationController:willShowViewController:animated:)])
        {
            [self.delegate ex2NavigationController:self willShowViewController:current animated:NO];
        }
			
		[self.contentView addSubview:current.view];
		current.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		[current.view setFrame:self.contentView.bounds];
		
		NSMutableArray *newItems = [[NSMutableArray alloc] initWithCapacity:self.viewControllers.count];
		for (UIViewController *vc in self.viewControllers)
		{
			[newItems addObject:vc.navigationItem];
			[vc.navigationItem.backBarButtonItem setTarget:self];
			[vc.navigationItem.backBarButtonItem setAction:@selector(backItemTapped:)];
		}
		self.navigationBar.items = newItems;
		
		if ([self.delegate respondsToSelector:@selector(ex2NavigationController:didShowViewController:animated:)])
        {
            [self.delegate ex2NavigationController:self didShowViewController:current animated:NO];
        }
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.viewControllers.lastObject viewWillAppear:animated];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.viewControllers.lastObject viewWillDisappear:animated];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.viewControllers.lastObject viewDidAppear:animated];
	}
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	// In iOS 4 make sure to pass this message
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[self.viewControllers.lastObject viewDidDisappear:animated];
	}
}

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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Overriden to allow any orientation.
    return YES;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

#pragma mark -
#pragma mark Navigation methods

- (void)animationStopped:(UIViewController *)disappearingController appearingController:(UIViewController *)appearingController
{
    //DLog(@"animation stopped");
    [disappearingController.view removeFromSuperview];
    
    // In iOS 4, these messages don't happen automatically
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[disappearingController viewDidDisappear:YES];
        [appearingController viewDidAppear:YES];
	}
    
    if ([self.delegate respondsToSelector:@selector(ex2NavigationController:didShowViewController:animated:)])
    { 
        [self.delegate ex2NavigationController:self didShowViewController:appearingController animated:YES];
    }
}

- (void)performAnimation:(UIViewController *)appearing appearingStart:(CGRect)appearingStart appearingEnd:(CGRect)appearingEnd disappearing:(UIViewController *)disappearing disappearingEnd:(CGRect)disappearingEnd
{
    //DLog(@"appearingStart: %@  appearingEnd: %@  disappearingEnd: %@", NSStringFromCGRect(appearingStart), NSStringFromCGRect(appearingEnd), NSStringFromCGRect(disappearingEnd));
    
    if (self.isAnimating)
        return;
    
    self.isAnimating = YES;
    
    appearing.view.frame = appearingStart;
    [self.contentView addSubview:appearing.view];
    
    // In iOS 4, these messages don't happen automatically
	if (SYSTEM_VERSION_LESS_THAN(@"5.0"))
	{
		[disappearing viewWillDisappear:YES];
        [appearing viewWillAppear:YES];
	}
    
    [UIView animateWithDuration:AnimationDuration
                          delay:0.0
                        options:AnimationCurve
                     animations:^ {
                         disappearing.view.frame = disappearingEnd;
                         appearing.view.frame = appearingEnd;
                     }
                     completion:^(BOOL finished) {
                         [self animationStopped:disappearing appearingController:appearing];
                         self.isAnimating = NO;
                     }];
}

- (void)animate:(UIViewController *)appearing disappearing:(UIViewController *)disappearing animation:(EX2NavigationControllerAnimation)animation
{
    if (self.isAnimating)
        return;
    
    CGRect appearingEnd = self.contentView.bounds;
    switch (animation)
	{
		case EX2NavigationControllerAnimationTop:
		{
            CGRect appearingStart = CGRectMake(0, -self.contentView.bounds.size.height, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
            CGRect disappearingEnd = disappearing.view.frame;
            disappearingEnd.origin.y = disappearingEnd.size.height;
            [self performAnimation:appearing appearingStart:appearingStart appearingEnd:appearingEnd disappearing:disappearing disappearingEnd:disappearingEnd];
            break;
		}
		case EX2NavigationControllerAnimationBottom:
		{
            CGRect appearingStart = CGRectMake(0, self.contentView.bounds.size.height, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
            CGRect disappearingEnd = disappearing.view.frame;
            disappearingEnd.origin.y = -disappearingEnd.size.height;
            [self performAnimation:appearing appearingStart:appearingStart appearingEnd:appearingEnd disappearing:disappearing disappearingEnd:disappearingEnd];
            break;
		}
		case EX2NavigationControllerAnimationRight:
		{
            CGRect appearingStart = CGRectMake(self.contentView.bounds.size.width, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
            CGRect disappearingEnd = disappearing.view.frame;
            disappearingEnd.origin.x = -disappearingEnd.size.width;
            [self performAnimation:appearing appearingStart:appearingStart appearingEnd:appearingEnd disappearing:disappearing disappearingEnd:disappearingEnd];
            break;
		}
		case EX2NavigationControllerAnimationLeft:
		{
            CGRect appearingStart = CGRectMake(-self.contentView.bounds.size.width, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
            CGRect disappearingEnd = disappearing.view.frame;
            disappearingEnd.origin.x = disappearingEnd.size.width;
            [self performAnimation:appearing appearingStart:appearingStart appearingEnd:appearingEnd disappearing:disappearing disappearingEnd:disappearingEnd];
            break;
		}
        case EX2NavigationControllerAnimationDefault:
		case EX2NavigationControllerAnimationNone:
		default:
		{
			[disappearing.view removeFromSuperview];
			[self.contentView addSubview:appearing.view];
            appearing.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
            appearing.view.frame = appearingEnd;
            
            if ([self.delegate respondsToSelector:@selector(ex2NavigationController:didShowViewController:animated:)])
            {
                [self.delegate ex2NavigationController:self didShowViewController:appearing animated:NO];
            }
            break;
		}
    }
}

- (void)setViewControllers:(NSArray *)vc animated:(BOOL)animated
{
	[self setViewControllers:vc withAnimation:(animated ? EX2NavigationControllerAnimationDefault : EX2NavigationControllerAnimationNone)];
}

- (void)setViewControllers:(NSArray *)vc withAnimation:(EX2NavigationControllerAnimation)animation
{
	UIViewController *disappearing = nil;
	if (self.viewControllers.count > 0)
		disappearing = self.viewControllers.lastObject;
	UIViewController *appearing = vc.lastObject;
	for (UIViewController *c in self.viewControllers)
	{
        c.ex2NavigationController = nil;
	}
    
    BOOL isAppearingAlreadyInStack = [self.viewControllers containsObject:appearing];

    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        for (UIViewController *controller in self.viewControllers)
        {
            if (controller != appearing)
            {
                [controller willMoveToParentViewController:nil];
                [controller removeFromParentViewController];
            }
        }
        
        for (UIViewController *controller in vc)
        {
            if (controller == appearing && isAppearingAlreadyInStack)
                continue;
            
            [self addChildViewController:controller];
        }
    }
    
	[self.viewControllers removeAllObjects];
	[self.viewControllers addObjectsFromArraySafe:vc];
	
	for (UIViewController *c in self.viewControllers)
	{
        c.ex2NavigationController = self;
	}
    
    // Perform the controller animation
    [self animate:appearing disappearing:disappearing animation:animation];
	
    // Setup the navigation bar
	NSMutableArray *newItems = [[NSMutableArray alloc] initWithCapacity:self.viewControllers.count];
	for (UIViewController *c in self.viewControllers)
	{
		[newItems addObject: c.navigationItem];
		[c.navigationItem.backBarButtonItem setTarget:self];
		[c.navigationItem.backBarButtonItem setAction:@selector(backItemTapped:)];
	}
	[self.navigationBar setItems:newItems animated:(animation != EX2NavigationControllerAnimationNone)];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        for (UIViewController *controller in self.viewControllers)
        {
            if (controller == appearing && isAppearingAlreadyInStack)
                continue;
            
            [controller didMoveToParentViewController:self];
        }
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
	[self pushViewController:viewController withAnimation:(animated ? EX2NavigationControllerAnimationDefault : EX2NavigationControllerAnimationNone)];
}

- (void)pushViewController:(UIViewController *)viewController withAnimation:(EX2NavigationControllerAnimation)animation
{
    if (self.isAnimating || !viewController)
        return;
    
	if ([self.delegate respondsToSelector:@selector(ex2NavigationController:willShowViewController:animated:)])
    {
        [self.delegate ex2NavigationController:self willShowViewController:viewController animated:(animation != EX2NavigationControllerAnimationNone)];
    }
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        [self addChildViewController:viewController];
    }
	
    viewController.ex2NavigationController = self;
	UIViewController *disappearing = nil;
	if (self.viewControllers.count > 0)
		disappearing = self.viewControllers.lastObject;
	[self.viewControllers addObjectSafe:viewController];
    
    // Perform the animation
    animation = animation == EX2NavigationControllerAnimationDefault ? EX2NavigationControllerAnimationRight : animation;
    [self animate:viewController disappearing:disappearing animation:animation];
	
	[self.navigationBar pushNavigationItem:viewController.navigationItem animated:(animation != EX2NavigationControllerAnimationNone)];
	[self.navigationBar.topItem.backBarButtonItem setTarget: self];
	[self.navigationBar.topItem.backBarButtonItem setAction: @selector(backItemTapped:)];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        [viewController didMoveToParentViewController:self];
    }
}

- (void)popViewControllerAnimated:(BOOL)animated
{
	[self popViewControllerWithAnimation:(animated ? EX2NavigationControllerAnimationDefault : EX2NavigationControllerAnimationNone)];
}

- (void)popViewControllerWithAnimation:(EX2NavigationControllerAnimation)animation
{
	if (self.isAnimating || self.viewControllers.count == 1)
		return;
    
	UIViewController *disappearing = self.viewControllers.lastObject;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0"))
    {
        [disappearing willMoveToParentViewController:nil];
        [disappearing removeFromParentViewController];
    }
    
    disappearing.ex2NavigationController = nil;
	[self.viewControllers removeLastObject];
	UIViewController *appearing = self.viewControllers.lastObject;
	
    if ([self.delegate respondsToSelector:@selector(ex2NavigationController:willShowViewController:animated:)])
    {
        [self.delegate ex2NavigationController:self willShowViewController:appearing animated:(animation != EX2NavigationControllerAnimationNone)];
    }
    
    animation = animation == EX2NavigationControllerAnimationDefault ? EX2NavigationControllerAnimationLeft : animation;
    [self animate:appearing disappearing:disappearing animation:animation];
    
    [self.navigationBar popNavigationItemAnimated:(animation != EX2NavigationControllerAnimationNone)];
}

- (void)popToRootViewControllerAnimated:(BOOL)animated
{
    if (!self.isAnimating && self.viewControllers.count > 1)
    {
        NSArray *array = @[[self.viewControllers objectAtIndex:0]];
        [self setViewControllers:array withAnimation:(animated ? EX2NavigationControllerAnimationLeft : EX2NavigationControllerAnimationNone)];
    }
}

- (BOOL)isRootViewController:(UIViewController *)viewController
{
    return viewController == [self.viewControllers firstObjectSafe];
}

- (void)setNavigationBarHidden:(BOOL)navigationBarHidden
{
    [self setNavigationBarHidden:navigationBarHidden animated:NO];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (_navigationBarHidden == hidden)
        return;
    
    _navigationBarHidden = hidden;
    
    void (^animationBlock)(void) = ^
    {
        if (hidden)
        {
            self.navigationBar.bottom = 0.;
            self.contentView.frame = self.view.bounds;
        }
        else
        {
            self.navigationBar.y = 0.;
            self.contentView.frame = CGRectMake(0, self.navigationBar.bottom, self.view.width, self.view.height - self.navigationBar.height);
        }
    };
    
    animated ? [UIView animateWithDuration:.33 animations:animationBlock] : animationBlock();
}

- (UIViewController *)rootViewController
{
    return [self.viewControllers firstObjectSafe];
}

- (void)backItemTapped:(id)sender
{
    
}

@end
