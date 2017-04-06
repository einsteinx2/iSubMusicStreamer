//
//  PageControlViewController.m
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PageControlViewController.h"
#import "CurrentPlaylistBackgroundViewController.h"
#import "LyricsViewController.h"
#import "DebugViewController.h"
#import "EqualizerViewController.h"
#import "PagingScrollView.h"

@interface PageControlViewController (PrivateMethods)

- (void)loadScrollViewWithPage:(int)page;
- (void)scrollViewDidScroll:(UIScrollView *)sender;

@end


@implementation PageControlViewController

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
//- (void)viewWillAppear:(BOOL)animated 
- (void)viewDidLoad
{
    //[super viewWillAppear:animated];
	[super viewDidLoad];
	
	self.numberOfPages = 1;
	if (settingsS.isLyricsEnabled) self.numberOfPages++;
	if (settingsS.isCacheStatusEnabled) self.numberOfPages++;
	
	// view controllers are created lazily
    // in the meantime, load the array with placeholders which will be replaced on demand
    NSMutableArray *controllers = [[NSMutableArray alloc] init];
    for (unsigned i = 0; i < self.numberOfPages; i++) {
        [controllers addObject:[NSNull null]];
    }
    self.viewControllers = controllers;
	
	// a page is the width of the scroll view
    self.scrollView.pagingEnabled = YES;
	CGSize contentSize;
	CGFloat height;
	if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) || IS_IPAD())
	{
		contentSize = CGSizeMake(320 * self.numberOfPages, self.numberOfPages == 1 ? 320 : 300);
		height = self.numberOfPages == 1 ? 320 : 300;
	}
	else
	{
		contentSize = CGSizeMake(300 * self.numberOfPages, self.numberOfPages == 1 ? 270 : 250);
		height = self.numberOfPages == 1 ? 320 : 300;
		//contentSize = CGSizeMake(300 * numberOfPages, numberOfPages == 1 ? 270 : 250);
		//height = numberOfPages == 1 ? 270 : 250;
	}
	self.scrollView.height = height;
    self.scrollView.contentSize = contentSize;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.delegate = self;
	
    self.pageControl.numberOfPages = self.numberOfPages;
    self.pageControl.currentPage = 0;
	
	if (self.numberOfPages == 1)
	{
		self.pageControlHolder.hidden = YES;
		self.pageControl.hidden = YES;
	}
	
	// Load all the pages for better performance
	/*for (int i = 0; i < numberOfPages; i++)
	{
		[self loadScrollViewWithPage:i];
	}*/
	
	// pages are created on demand
    // load the visible page
    // load the page on either side to avoid flashes when the user starts scrolling
	[self loadScrollViewWithPage:0];
    [self loadScrollViewWithPage:1];
	
	self.swipeDetector = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideSongInfo)];
	self.swipeDetector.delegate = (id<UIGestureRecognizerDelegate>)self;
	self.swipeDetector.direction = UISwipeGestureRecognizerDirectionRight;
	[self.scrollView addGestureRecognizer:self.swipeDetector];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	return YES;
}

- (void)resetScrollView
{
//DLog(@"PageControlViewController resetScrollView called");
	[self.scrollView setContentOffset:CGPointZero animated:YES];
}


- (void)loadScrollViewWithPage:(int)page 
{
    if (page < 0) return;
    if (page >= self.numberOfPages) return;
	
	UIViewController *controller = (UIViewController *) [self.viewControllers objectAtIndexSafe:page];
    if ((NSNull *)controller != [NSNull null]) return; 
	
    // Replace the placeholder
	switch (page) 
	{
		case 0:
			controller = [[CurrentPlaylistBackgroundViewController alloc] initWithNibName:@"CurrentPlaylistBackgroundViewController" bundle:nil];
			break;
		case 1:
			if (settingsS.isLyricsEnabled)
				controller = [[LyricsViewController alloc] initWithNibName:nil bundle:nil];
			else if (settingsS.isCacheStatusEnabled)
				controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
			break;
		case 2:
			controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
		default:
			break;
	}
	
	[self.viewControllers replaceObjectAtIndex:page withObject:controller];
	
    // Add the controller's view to the scroll view
	/*CGRect frame = scrollView.frame;
	frame.origin.x = frame.size.width * page;
	frame.origin.y = 0;*/
	CGRect frame = CGRectMake(self.scrollView.frame.size.width * page, 0, self.scrollView.frame.size.width, self.scrollView.frame.size.height);
	controller.view.frame = frame;
	[self.scrollView addSubview:controller.view];
}

- (void)unloadScrollViewPage:(NSUInteger)page
{
	UIViewController *controller = (UIViewController *) [self.viewControllers objectAtIndexSafe:page];
	if ((NSNull *)controller != [NSNull null])
	{
		[controller.view removeFromSuperview];
		[self.viewControllers replaceObjectAtIndex:page withObject:[NSNull null]];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)sender 
{
    // We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
    // which a scroll event generated from the user hitting the page control triggers updates from
    // the delegate method. We use a boolean to disable the delegate logic when the page control is used.
    if (self.pageControlUsed) 
	{
		// Send a notification so the playlist view hides the edit controls
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideEditControls"];
		
        // do nothing - the scroll was initiated from the page control, not the user dragging
        return;
    }
	
    // Switch the indicator when more than 50% of the previous/next page is visible
    CGFloat pageWidth = self.scrollView.bounds.size.width;
    int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    self.pageControl.currentPage = page;
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
	[self loadScrollViewWithPage:page + 1];
	
	/*// Unload uneeded pages
	for (int i = 0; i < [viewControllers count]; i++)
	{
		if (i < page - 1 || i > page + 1)
		{
			[self unloadScrollViewPage:i];
		}
	}*/
	
	// Send a notification so the playlist view hides the edit controls
	[NSNotificationCenter postNotificationToMainThreadWithName:@"hideEditControls"];
	
    // A possible optimization would be to unload the views+controllers which are no longer visible
	
	
	
	/*if (NSClassFromString(@"UISwipeGestureRecognizer"))
	{
		if (page == 0 || page == numberOfPages-1)
		{
			UISwipeGestureRecognizerDirection direction = UISwipeGestureRecognizerDirectionLeft;
			if (page == 0) direction = UISwipeGestureRecognizerDirectionRight;
			
			swipeDetector.direction = direction;
			//[self createSwipeDetector:controller.view direction:direction];
			//[self createSwipeDetectorWithDirection:direction];
		}
	}*/
}


// At the begin of scroll dragging, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.pageControlUsed = NO;
}


// At the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    self.pageControlUsed = NO;
}


- (IBAction)changePage:(id)sender 
{
    int page = (int)self.pageControl.currentPage;
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
    [self loadScrollViewWithPage:page + 1];
    
	// update the scroll view to the appropriate page
    CGRect frame = self.scrollView.bounds;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;
    [self.scrollView scrollRectToVisible:frame animated:YES];
    
	// Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
    self.pageControlUsed = YES;
}

- (void)hideSongInfo
{
	[NSNotificationCenter postNotificationToMainThreadWithName:@"hideSongInfo"];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	for (UIViewController *subView in self.viewControllers)
	{
		if ((NSNull*)subView != [NSNull null])
		{
			[subView.view removeFromSuperview];
			//[subView viewDidDisappear:NO];
		}
	}
	
	self.viewControllers = nil;
}

- (void)dealloc 
{
	[self.scrollView removeGestureRecognizer:self.swipeDetector];
}

@end
