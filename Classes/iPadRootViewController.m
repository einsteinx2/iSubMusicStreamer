//
//  RootView.m
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import "iPadRootViewController.h"
#import "CustomUITableView.h"

#import "MenuViewController.h"
#import "StackScrollViewController.h"


@interface UIViewExt : UIView
@end


@implementation UIViewExt

- (UIView *)hitTest:(CGPoint)pt withEvent:(UIEvent *)event 
{   
	UIView *viewToReturn=nil;
	CGPoint pointToReturn;
	
	UIView *uiLeftView = (UIView *)[[self subviews] objectAtIndex:1];
	
	if ([[uiLeftView subviews] objectAtIndex:0])
	{
		UIView* uiScrollView = [[uiLeftView subviews] objectAtIndex:0];	
		
		if ([[uiScrollView subviews] objectAtIndex:0]) 
		{	 
			UIView *uiMainView = [[uiScrollView subviews] objectAtIndex:1];	
			
			for (UIView *subView in [uiMainView subviews]) 
			{
				CGPoint point  = [subView convertPoint:pt fromView:self];
				if ([subView pointInside:point withEvent:event]) 
				{
					viewToReturn = subView;
					pointToReturn = point;
				}
			}
		}
	}
	
	if(viewToReturn != nil) 
	{
		return [viewToReturn hitTest:pointToReturn withEvent:event];		
	}
	
	return [super hitTest:pt withEvent:event];
}

@end

@implementation iPadRootViewController
@synthesize menuViewController, stackScrollViewController;
@synthesize rootView, leftMenuView, rightSlideView;

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{		
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.rootView = [[UIViewExt alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	self.rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
	[self.rootView setBackgroundColor:[UIColor clearColor]];
	
	self.leftMenuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, self.view.frame.size.height)];
	self.leftMenuView.autoresizingMask = UIViewAutoresizingFlexibleHeight;	
	self.menuViewController = [[MenuViewController alloc] initWithFrame:CGRectMake(0, 0, self.leftMenuView.frame.size.width, self.leftMenuView.frame.size.height)];
	[self.menuViewController.view setBackgroundColor:[UIColor clearColor]];
	[self.menuViewController viewWillAppear:FALSE];
	[self.menuViewController viewDidAppear:FALSE];
	[self.leftMenuView addSubview:self.menuViewController.view];
	
	self.rightSlideView = [[UIView alloc] initWithFrame:CGRectMake(self.leftMenuView.frame.size.width, 0, self.rootView.frame.size.width - self.leftMenuView.frame.size.width, self.rootView.frame.size.height)];
	self.rightSlideView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
	self.stackScrollViewController = [[StackScrollViewController alloc] init];	
	[self.stackScrollViewController.view setFrame:CGRectMake(0, 0, self.rightSlideView.frame.size.width, self.rightSlideView.frame.size.height)];
	[self.stackScrollViewController.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight];
	[self.stackScrollViewController viewWillAppear:NO];
	[self.stackScrollViewController viewDidAppear:NO];
	[self.rightSlideView addSubview:self.stackScrollViewController.view];
	
	[self.rootView addSubview:self.leftMenuView];
	[self.rootView addSubview:self.rightSlideView];
	self.view.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.7];
	[self.view addSubview:rootView];
    
    // On iOS 7, don't let the status bar text cover the content
    if (IS_IOS7())
    {
        self.rootView.height -= 20.;
        self.rootView.y += 20.;
    }
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation 
{
	[self.menuViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[self.stackScrollViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.menuViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.stackScrollViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.menuViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.stackScrollViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}	
- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning];
}


@end
