//
//  StackScrollViewController.m
//  SlidingView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import "StackScrollViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "StackContainerView.h"

const NSInteger SLIDE_VIEWS_MINUS_X_POSITION = 0;//-190;//-130;
const NSInteger SLIDE_VIEWS_START_X_POS = 0;
const NSTimeInterval SLIDE_ANIMATION_DURATION = 0.2;
const NSTimeInterval BOUNCE_ANIMATION_DURATION = 0.06;
//TODO: calc bounce anim dur & dist based on distance of slide so that its the same speed per pixel
const CGFloat BOUNCE_DISTANCE = 10.0;

@implementation StackScrollViewController

@synthesize slideViews, borderViews, viewControllersStack, slideStartPosition, viewAtLeft, viewAtLeft2, viewAtRight, viewAtRight2, viewAtLeftAtTouchBegan, viewAtRightAtTouchBegan, dragDirection, viewXPosition, displacementPosition, lastTouchPoint, positionOfViewAtLeftAtTouchBegan, positionOfViewAtRightAtTouchBegan, isSlidingEnabled;

- (id)init
{
	if((self = [super init])) 
	{
        isSlidingEnabled = YES;
        
		viewControllersStack = [[NSMutableArray alloc] init]; 
		borderViews = [[UIView alloc] initWithFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION - 2, -2, 2, self.view.frame.size.height)];
		[borderViews setBackgroundColor:[UIColor clearColor]];
		UIView* verticalLineView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, borderViews.frame.size.height)];
		[verticalLineView1 setBackgroundColor:[UIColor whiteColor]];
		[verticalLineView1 setTag:1];
		[verticalLineView1 setHidden:YES];
		[borderViews addSubview:verticalLineView1];
		
		UIView* verticalLineView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, borderViews.frame.size.height)];
		[verticalLineView2 setBackgroundColor:[UIColor grayColor]];
		[verticalLineView2 setTag:2];
		[verticalLineView2 setHidden:YES];		
		[borderViews addSubview:verticalLineView2];
		
		[self.view addSubview:borderViews];
		
		slideViews = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
		[slideViews setBackgroundColor:[UIColor clearColor]];
		[self.view setBackgroundColor:[UIColor clearColor]];
		[self.view setFrame:slideViews.frame];
		self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		viewXPosition = 0;
		lastTouchPoint = -1;
		
		dragDirection = StackScrollViewDragNone;
		
		viewAtLeft = nil;
		viewAtLeft2 = nil;
		viewAtRight = nil;
		viewAtRight2 = nil;
		viewAtRightAtTouchBegan = nil;
		
		UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
		panRecognizer.maximumNumberOfTouches = 1;
		panRecognizer.delaysTouchesBegan = NO;
		panRecognizer.delaysTouchesEnded = NO;
		panRecognizer.cancelsTouchesInView = NO;
		[self.view addGestureRecognizer:panRecognizer];
		
		[self.view addSubview:slideViews];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPlayer) 
													 name:ISMSNotification_ShowPlayer object:nil];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIView *)slideViewAtIndex:(NSUInteger)index
{
	return (UIView *)[[slideViews subviews] objectAtIndexSafe:index];
}

- (void)showPlayer
{
	//TODO: this is buggy
	return;
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];			
	//[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
	for (UIView *subView in slideViews.subviews)
	{
		if (subView.x < 0.)
			subView.x = 0.;
	}
	//if (((UIView *)[slideViews.subviews firstObjectSafe]).x < 0.)
	{
		
	}
	[UIView commitAnimations];	
}

- (void)arrangeVerticalBar 
{
	if ([[self.slideViews subviews] count] > 2) 
	{
		[[self.borderViews viewWithTag:2] setHidden:YES];
		[[self.borderViews viewWithTag:1] setHidden:YES];
		
		NSInteger stackCount = 0;
		if (self.viewAtLeft != nil ) 
		{
			stackCount = [[self.slideViews subviews] indexOfObject:self.viewAtLeft];
		}
		
		if (self.viewAtLeft != nil && self.viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION) 
		{
			stackCount += 1;
		}
		
		if (stackCount == 2) 
		{
			[[self.borderViews viewWithTag:2] setHidden:YES];
		}
		if (stackCount >= 3)
		{
			[[self.borderViews viewWithTag:2] setHidden:YES];
			[[self.borderViews viewWithTag:1] setHidden:YES];
		}
	}
}


- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer
{    
    if (!self.isSlidingEnabled)
        return;
    
	CGPoint translatedPoint = [recognizer translationInView:self.view];
	
	if (recognizer.state == UIGestureRecognizerStateBegan) 
	{
		self.displacementPosition = 0;
		self.positionOfViewAtRightAtTouchBegan = viewAtRight.frame.origin;
		self.positionOfViewAtLeftAtTouchBegan = viewAtLeft.frame.origin;
		self.viewAtRightAtTouchBegan = viewAtRight;
		self.viewAtLeftAtTouchBegan = viewAtLeft;
		[self.viewAtLeft.layer removeAllAnimations];
		[self.viewAtRight.layer removeAllAnimations];
		[self.viewAtRight2.layer removeAllAnimations];
		[self.viewAtLeft2.layer removeAllAnimations];
		if (self.viewAtLeft2 != nil) 
		{
			NSInteger viewAtLeft2Position = [[self.slideViews subviews] indexOfObject:self.viewAtLeft2];
			if (viewAtLeft2Position > 0) 
			{
				[((UIView*)[[self.slideViews subviews] objectAtIndex:viewAtLeft2Position-1]) setHidden:NO];
			}
		}
		
		[self arrangeVerticalBar];
	}
	
	
	CGPoint location =  [recognizer locationInView:self.view];
	
	if (self.lastTouchPoint != -1) 
	{
		if (location.x < self.lastTouchPoint) 
		{			
			if (self.dragDirection == StackScrollViewDragRight) 
			{
				self.positionOfViewAtRightAtTouchBegan = self.viewAtRight.frame.origin;
				self.positionOfViewAtLeftAtTouchBegan = self.viewAtLeft.frame.origin;
				self.displacementPosition = translatedPoint.x * -1;
			}				
			
			self.dragDirection = StackScrollViewDragLeft;
			
			if (self.viewAtRight != nil) 
			{
				if (self.viewAtLeft.frame.origin.x <= SLIDE_VIEWS_MINUS_X_POSITION) 
				{						
					if ([[self.slideViews subviews] indexOfObject:self.viewAtRight] < ([[self.slideViews subviews] count]-1)) 
					{
						self.viewAtLeft2 = self.viewAtLeft;
						self.viewAtLeft = self.viewAtRight;
						self.viewAtRight2.hidden = NO;
						self.viewAtRight = viewAtRight2;
						if ([[self.slideViews subviews] indexOfObject:self.viewAtRight] < ([[self.slideViews subviews] count]-1))
						{
							self.viewAtRight2 = [[self.slideViews subviews] objectAtIndex:[[self.slideViews subviews] indexOfObject:self.viewAtRight] + 1];
						}
						else 
						{
							self.viewAtRight2 = nil;
						}							
						self.positionOfViewAtRightAtTouchBegan = self.viewAtRight.frame.origin;
						self.positionOfViewAtLeftAtTouchBegan = self.viewAtLeft.frame.origin;
						self.displacementPosition = translatedPoint.x * -1;							
						if ([[self.slideViews subviews] indexOfObject:self.viewAtLeft2] > 1)
						{
							[[[self.slideViews subviews] objectAtIndex:[[self.slideViews subviews] indexOfObject:self.viewAtLeft2] - 2] setHidden:YES];
						}
					}
				}
				
				if (self.viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION && self.viewAtRight.frame.origin.x + self.viewAtRight.frame.size.width > self.view.frame.size.width) 
				{
					if ((self.positionOfViewAtRightAtTouchBegan.x + translatedPoint.x + self.displacementPosition + self.viewAtRight.frame.size.width) <= self.view.frame.size.width) 
					{
						[self.viewAtRight setFrame:CGRectMake(self.view.frame.size.width - self.viewAtRight.frame.size.width, self.viewAtRight.frame.origin.y, self.viewAtRight.frame.size.width, self.viewAtRight.frame.size.height)];
					}
					else
					{
						[self.viewAtRight setFrame:CGRectMake(self.positionOfViewAtRightAtTouchBegan.x + translatedPoint.x + self.displacementPosition, self.viewAtRight.frame.origin.y, self.viewAtRight.frame.size.width, self.viewAtRight.frame.size.height)];
					}
				}
				else if (([[self.slideViews subviews] indexOfObject:self.viewAtRight] == [[self.slideViews subviews] count]-1) && self.viewAtRight.frame.origin.x <= (self.view.frame.size.width - self.viewAtRight.frame.size.width)) 
				{
					if ((self.positionOfViewAtRightAtTouchBegan.x + translatedPoint.x + self.displacementPosition) <= SLIDE_VIEWS_MINUS_X_POSITION)
					{
						[self.viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, self.viewAtRight.frame.origin.y, self.viewAtRight.frame.size.width, self.viewAtRight.frame.size.height)];
					}
					else
					{
						[self.viewAtRight setFrame:CGRectMake(self.positionOfViewAtRightAtTouchBegan.x + translatedPoint.x + self.displacementPosition, self.viewAtRight.frame.origin.y, self.viewAtRight.frame.size.width, self.viewAtRight.frame.size.height)];
					}
				}
				else
				{						
					if (self.positionOfViewAtLeftAtTouchBegan.x + translatedPoint.x + self.displacementPosition <= SLIDE_VIEWS_MINUS_X_POSITION) 
					{
						[self.viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, self.viewAtLeft.frame.origin.y, self.viewAtLeft.frame.size.width, self.viewAtLeft.frame.size.height)];
					}
					else
					{
						[self.viewAtLeft setFrame:CGRectMake(self.positionOfViewAtLeftAtTouchBegan.x + translatedPoint.x + self.displacementPosition , self.viewAtLeft.frame.origin.y, self.viewAtLeft.frame.size.width, self.viewAtLeft.frame.size.height)];
					}						
					[self.viewAtRight setFrame:CGRectMake(self.viewAtLeft.frame.origin.x + self.viewAtLeft.frame.size.width, self.viewAtRight.frame.origin.y, self.viewAtRight.frame.size.width, self.viewAtRight.frame.size.height)];
					
					if (self.viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION)
					{
						self.positionOfViewAtRightAtTouchBegan = self.viewAtRight.frame.origin;
						self.positionOfViewAtLeftAtTouchBegan = self.viewAtLeft.frame.origin;
						self.displacementPosition = translatedPoint.x * -1;
					}
					
				}
				
			}
			else 
			{
				[self.viewAtLeft setFrame:CGRectMake(self.positionOfViewAtLeftAtTouchBegan.x + translatedPoint.x + self.displacementPosition , self.viewAtLeft.frame.origin.y, self.viewAtLeft.frame.size.width, self.viewAtLeft.frame.size.height)];
			}
			
			[self arrangeVerticalBar];
			
		}
		else if (location.x > self.lastTouchPoint) 
		{	
			if (self.dragDirection == StackScrollViewDragLeft)
			{
				self.positionOfViewAtRightAtTouchBegan = self.viewAtRight.frame.origin;
				self.positionOfViewAtLeftAtTouchBegan = self.viewAtLeft.frame.origin;
				self.displacementPosition = translatedPoint.x;
			}	
			
			self.dragDirection = StackScrollViewDragRight;
			
			if (self.viewAtLeft != nil) 
			{
				if (self.viewAtRight.frame.origin.x >= self.view.frame.size.width) 
				{
					if ([[self.slideViews subviews] indexOfObject:self.viewAtLeft] > 0) 
					{							
						self.viewAtRight2.hidden = YES;
						self.viewAtRight2 = self.viewAtRight;
						self.viewAtRight = self.viewAtLeft;
						self.viewAtLeft = self.viewAtLeft2;						
						if ([[self.slideViews subviews] indexOfObject:self.viewAtLeft] > 0)
						{
							self.viewAtLeft2 = [[self.slideViews subviews] objectAtIndex:[[self.slideViews subviews] indexOfObject:self.viewAtLeft] - 1];
							self.viewAtLeft2.hidden = NO;
						}
						else
						{
							self.viewAtLeft2 = nil;
						}
						self.positionOfViewAtRightAtTouchBegan = self.viewAtRight.frame.origin;
						self.positionOfViewAtLeftAtTouchBegan = self.viewAtLeft.frame.origin;
						self.displacementPosition = translatedPoint.x;
						
						[self arrangeVerticalBar];
					}
				}
				
				if((viewAtRight.frame.origin.x < (viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width)) && viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION)
				{						
					if ((positionOfViewAtRightAtTouchBegan.x + translatedPoint.x - displacementPosition) >= (viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width)) 
					{
						[viewAtRight setFrame:CGRectMake(viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
					}
					else 
					{
						[viewAtRight setFrame:CGRectMake(positionOfViewAtRightAtTouchBegan.x + translatedPoint.x - displacementPosition, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
					}
				}
				else if ([[slideViews subviews] indexOfObject:viewAtLeft] == 0) 
				{
					if (viewAtRight == nil)
					{
						[viewAtLeft setFrame:CGRectMake(positionOfViewAtLeftAtTouchBegan.x + translatedPoint.x - displacementPosition, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
					}
					else
					{
						[viewAtRight setFrame:CGRectMake(positionOfViewAtRightAtTouchBegan.x + translatedPoint.x - displacementPosition, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
						if (viewAtRight.frame.origin.x - viewAtLeft.frame.size.width < SLIDE_VIEWS_MINUS_X_POSITION) 
						{
							[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						}
						else
						{
							[viewAtLeft setFrame:CGRectMake(viewAtRight.frame.origin.x - viewAtLeft.frame.size.width, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						}
					}
				}					
				else
				{
					if ((positionOfViewAtRightAtTouchBegan.x + translatedPoint.x - displacementPosition) >= self.view.frame.size.width)
					{
						[viewAtRight setFrame:CGRectMake(self.view.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
					}
					else 
					{
						[viewAtRight setFrame:CGRectMake(positionOfViewAtRightAtTouchBegan.x + translatedPoint.x - displacementPosition, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
					}
					if (viewAtRight.frame.origin.x - viewAtLeft.frame.size.width < SLIDE_VIEWS_MINUS_X_POSITION) 
					{
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
					}
					else
					{
						[viewAtLeft setFrame:CGRectMake(viewAtRight.frame.origin.x - viewAtLeft.frame.size.width, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
					}
					if (viewAtRight.frame.origin.x >= self.view.frame.size.width) 
					{
						positionOfViewAtRightAtTouchBegan = viewAtRight.frame.origin;
						positionOfViewAtLeftAtTouchBegan = viewAtLeft.frame.origin;
						displacementPosition = translatedPoint.x;
					}
					
					[self arrangeVerticalBar];
				}
				
			}
			
			[self arrangeVerticalBar];
		}
	}
	
	lastTouchPoint = location.x;
	
	// STATE END	
	if (recognizer.state == UIGestureRecognizerStateEnded) 
	{
		if (dragDirection == StackScrollViewDragLeft) 
		{
			if (viewAtRight != nil) 
			{
				if ([[slideViews subviews] indexOfObject:viewAtLeft] == 0 && !(viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION || viewAtLeft.frame.origin.x == SLIDE_VIEWS_START_X_POS))
				{
					[UIView beginAnimations:nil context:NULL];
					[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
					[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
					[UIView setAnimationBeginsFromCurrentState:YES];
					if (viewAtLeft.frame.origin.x < SLIDE_VIEWS_START_X_POS && viewAtRight != nil) 
					{
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];
					}
					else
					{
						/*//Drop Card View Animation
						if (([self slideViewAtIndex:0].frame.origin.x + 200) >= (self.view.frame.origin.x + [self slideViewAtIndex:0].frame.size.width))
						{
							NSInteger viewControllerCount = [viewControllersStack count];
							
							if (viewControllerCount > 1) 
							{
								for (int i = viewControllerCount - 1; i >= 1; i--)
								{
									UIView *viewToRemove = [self slideViewAtIndex:i];
									viewXPosition = self.view.frame.size.width - viewToRemove.frame.size.width;
									[viewToRemove removeFromSuperview];
									[viewControllersStack removeObjectAtIndex:i];
								}
								
								[[borderViews viewWithTag:3] setHidden:YES];
								[[borderViews viewWithTag:2] setHidden:YES];
								[[borderViews viewWithTag:1] setHidden:YES];
								
							}
							
							// Removes the selection of row for the first slide view
							for (UIView* tableView in [[[slideViews subviews] objectAtIndex:0] subviews])
							{
								if([tableView isKindOfClass:[UITableView class]])
								{
									NSIndexPath* selectedRow =  [(UITableView*)tableView indexPathForSelectedRow];
									NSArray *indexPaths = @[selectedRow];
									[(UITableView*)tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:NO];
								}
							}
							viewAtLeft2 = nil;
							viewAtRight = nil;
							viewAtRight2 = nil;							 
						}*/
						
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						if (viewAtRight != nil)
						{
							[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
						}
					}
					[UIView commitAnimations];
				}
				else if (viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION && viewAtRight.frame.origin.x + viewAtRight.frame.size.width > self.view.frame.size.width)
				{
					[UIView beginAnimations:nil context:NULL];
					[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
					[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
					[UIView setAnimationBeginsFromCurrentState:YES];
					[viewAtRight setFrame:CGRectMake(self.view.frame.size.width - viewAtRight.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
					[UIView commitAnimations];						
				}	
				else if (viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION && viewAtRight.frame.origin.x + viewAtRight.frame.size.width < self.view.frame.size.width) 
				{
					[UIView beginAnimations:@"RIGHT-WITH-RIGHT" context:NULL];
					[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
					[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
					[UIView setAnimationBeginsFromCurrentState:YES];
					[viewAtRight setFrame:CGRectMake(self.view.frame.size.width - viewAtRight.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
					[UIView commitAnimations];
				}
				else if (viewAtLeft.frame.origin.x > SLIDE_VIEWS_MINUS_X_POSITION)
				{
					[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
                    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
					[UIView setAnimationBeginsFromCurrentState:YES];
					if ((viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width > self.view.frame.size.width) && viewAtLeft.frame.origin.x < (self.view.frame.size.width - (viewAtLeft.frame.size.width)/2)) 
					{
						[UIView beginAnimations:@"LEFT-WITH-LEFT" context:nil];
						[viewAtLeft setFrame:CGRectMake(self.view.frame.size.width - viewAtLeft.frame.size.width, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						
						//Show bounce effect
						[viewAtRight setFrame:CGRectMake(self.view.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
					}
					else
					{
						[UIView beginAnimations:@"LEFT-WITH-RIGHT" context:nil];	
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						if (positionOfViewAtLeftAtTouchBegan.x + viewAtLeft.frame.size.width <= self.view.frame.size.width)
						{
							[viewAtRight setFrame:CGRectMake((self.view.frame.size.width - viewAtRight.frame.size.width), viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
						}
						else
						{
							[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
						}
						
						//Show bounce effect
						[viewAtRight2 setFrame:CGRectMake(viewAtRight.frame.origin.x + viewAtRight.frame.size.width, viewAtRight2.frame.origin.y, viewAtRight2.frame.size.width, viewAtRight2.frame.size.height)];
					}
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
					[UIView commitAnimations];
				}
				
			}
			else
			{
				[UIView beginAnimations:nil context:NULL];
				[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
				[UIView setAnimationBeginsFromCurrentState:YES];
				[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
				[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
				[UIView commitAnimations];
			}
		}
		else if (dragDirection == StackScrollViewDragRight) 
		{
			if (viewAtLeft != nil) 
			{
				if ([[slideViews subviews] indexOfObject:viewAtLeft] == 0 && !(viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION || viewAtLeft.frame.origin.x == SLIDE_VIEWS_START_X_POS))
				{
					[UIView beginAnimations:nil context:NULL];
					[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];			
					[UIView setAnimationBeginsFromCurrentState:YES];
					[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
					if (viewAtLeft.frame.origin.x > SLIDE_VIEWS_MINUS_X_POSITION || viewAtRight == nil)
					{
						/*//Drop Card View Animation
						if (([self slideViewAtIndex:0].frame.origin.x + 200) >= (self.view.frame.origin.x + [self slideViewAtIndex:0].frame.size.width)) 
						{
							NSInteger viewControllerCount = [viewControllersStack count];
							if (viewControllerCount > 1) 
							{
								for (int i = viewControllerCount - 1; i >= 1; i--) 
								{									
									UIView *viewToRemove = [self slideViewAtIndex:i];
									viewXPosition = self.view.frame.size.width - viewToRemove.frame.size.width;
									[viewToRemove removeFromSuperview];
									[viewControllersStack removeObjectAtIndex:i];
								}
								[[borderViews viewWithTag:3] setHidden:YES];
								[[borderViews viewWithTag:2] setHidden:YES];
								[[borderViews viewWithTag:1] setHidden:YES];
							}
							
							// Removes the selection of row for the first slide view
							for (UIView* tableView in [[[slideViews subviews] objectAtIndex:0] subviews]) 
							{
								if([tableView isKindOfClass:[UITableView class]])
								{
									NSIndexPath* selectedRow =  [(UITableView*)tableView indexPathForSelectedRow];
									NSArray *indexPaths = @[selectedRow];
									[(UITableView*)tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:NO];
								}
							}
							
							viewAtLeft2 = nil;
							viewAtRight = nil;
							viewAtRight2 = nil;							 
						}*/
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						if (viewAtRight != nil) 
						{
							[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];
						}
					}
					else
					{
						[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
						[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];
					}
					[UIView commitAnimations];
				}
				else if (viewAtRight.frame.origin.x < self.view.frame.size.width) 
				{
					if((viewAtRight.frame.origin.x < (viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width)) && viewAtRight.frame.origin.x < (self.view.frame.size.width - (viewAtRight.frame.size.width/2)))
					{
						[UIView beginAnimations:@"RIGHT-WITH-RIGHT" context:NULL];
						[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
						[UIView setAnimationBeginsFromCurrentState:YES];
						[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
						[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];						
						[UIView setAnimationDelegate:self];
						[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
						[UIView commitAnimations];
					}				
					else
					{
						[UIView beginAnimations:@"RIGHT-WITH-LEFT" context:NULL];
						[UIView setAnimationDuration:SLIDE_ANIMATION_DURATION];
						[UIView setAnimationBeginsFromCurrentState:YES];
						[UIView setAnimationTransition:UIViewAnimationTransitionNone forView:nil cache:YES];
						if([[slideViews subviews] indexOfObject:viewAtLeft] > 0)
						{ 
							if (positionOfViewAtRightAtTouchBegan.x  + viewAtRight.frame.size.width <= self.view.frame.size.width) 
							{							
								[viewAtLeft setFrame:CGRectMake(self.view.frame.size.width - viewAtLeft.frame.size.width, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
							}
							else
							{							
								[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft2.frame.size.width, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
							}
							[viewAtRight setFrame:CGRectMake(self.view.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];		
						}
						else
						{
							[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
							[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION + viewAtLeft.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width,viewAtRight.frame.size.height)];
						}
						[UIView setAnimationDelegate:self];
						[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
						[UIView commitAnimations];
					}
					
				}
			}			
		}
		lastTouchPoint = -1;
		dragDirection = StackScrollViewDragNone;
	}
}

- (void)bounceBack:(NSString*)animationID finished:(NSNumber*)finished context:(void*)context 
{	
	BOOL isBouncing = NO;
	
	if(dragDirection == StackScrollViewDragNone && [finished boolValue])
	{
		[viewAtLeft.layer removeAllAnimations];
		[viewAtRight.layer removeAllAnimations];
		// TODO: get rid of this hack and figure out the actual cause of the problem. Somehow viewAtRight2 is being released
		if ([viewAtRight2 respondsToSelector:@selector(layer)])
			[viewAtRight2.layer removeAllAnimations];
		[viewAtLeft2.layer removeAllAnimations];
		if ([animationID isEqualToString:@"LEFT-WITH-LEFT"] && viewAtLeft2.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION)
		{
			CABasicAnimation *bounceAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimation.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimation.fromValue = [NSValue valueWithCGPoint:viewAtLeft.center];
			bounceAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtLeft.center.x -10, viewAtLeft.center.y)];
			bounceAnimation.repeatCount = 0;
			bounceAnimation.autoreverses = YES;
			bounceAnimation.fillMode = kCAFillModeBackwards;
			bounceAnimation.removedOnCompletion = YES;
			bounceAnimation.additive = NO;
			[viewAtLeft.layer addAnimation:bounceAnimation forKey:@"bounceAnimation"];
			
			[viewAtRight setHidden:NO];
			CABasicAnimation *bounceAnimationForRight = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimationForRight.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimationForRight.fromValue = [NSValue valueWithCGPoint:viewAtRight.center];
			bounceAnimationForRight.toValue = [NSValue valueWithCGPoint:CGPointMake((viewAtRight.center.x - 20), viewAtRight.center.y)];
			bounceAnimationForRight.repeatCount = 0;
			bounceAnimationForRight.autoreverses = YES;
			bounceAnimationForRight.fillMode = kCAFillModeBackwards;
			bounceAnimationForRight.removedOnCompletion = YES;
			bounceAnimationForRight.additive = NO;
			[viewAtRight.layer addAnimation:bounceAnimationForRight forKey:@"bounceAnimationRight"];
		}
		else if ([animationID isEqualToString:@"LEFT-WITH-RIGHT"]  && viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION)
		{
			CABasicAnimation *bounceAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimation.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimation.fromValue = [NSValue valueWithCGPoint:viewAtRight.center];
			bounceAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtRight.center.x -10, viewAtRight.center.y)];
			bounceAnimation.repeatCount = 0;
			bounceAnimation.autoreverses = YES;
			bounceAnimation.fillMode = kCAFillModeBackwards;
			bounceAnimation.removedOnCompletion = YES;
			bounceAnimation.additive = NO;
			[viewAtRight.layer addAnimation:bounceAnimation forKey:@"bounceAnimation"];
			
			
			[viewAtRight2 setHidden:NO];
			CABasicAnimation *bounceAnimationForRight2 = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimationForRight2.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimationForRight2.fromValue = [NSValue valueWithCGPoint:viewAtRight2.center];
			bounceAnimationForRight2.toValue = [NSValue valueWithCGPoint:CGPointMake((viewAtRight2.center.x - 20), viewAtRight2.center.y)];
			bounceAnimationForRight2.repeatCount = 0;
			bounceAnimationForRight2.autoreverses = YES;
			bounceAnimationForRight2.fillMode = kCAFillModeBackwards;
			bounceAnimationForRight2.removedOnCompletion = YES;
			bounceAnimationForRight2.additive = NO;
			[viewAtRight2.layer addAnimation:bounceAnimationForRight2 forKey:@"bounceAnimationRight2"];
		}
		else if ([animationID isEqualToString:@"RIGHT-WITH-RIGHT"]) 
		{
			CABasicAnimation *bounceAnimationLeft = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimationLeft.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimationLeft.fromValue = [NSValue valueWithCGPoint:viewAtLeft.center];
			//bounceAnimationLeft.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtLeft.center.x +10, viewAtLeft.center.y)];
			bounceAnimationLeft.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtLeft.center.x + BOUNCE_DISTANCE, viewAtLeft.center.y)];
			bounceAnimationLeft.repeatCount = 0;
			bounceAnimationLeft.autoreverses = YES;
			bounceAnimationLeft.fillMode = kCAFillModeBackwards;
			bounceAnimationLeft.removedOnCompletion = YES;
			bounceAnimationLeft.additive = NO;
			[viewAtLeft.layer addAnimation:bounceAnimationLeft forKey:@"bounceAnimationLeft"];
			
			CABasicAnimation *bounceAnimationRight = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimationRight.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimationRight.fromValue = [NSValue valueWithCGPoint:viewAtRight.center];
			//bounceAnimationRight.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtRight.center.x +10, viewAtRight.center.y)];
			bounceAnimationRight.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtRight.center.x + BOUNCE_DISTANCE, viewAtRight.center.y)];
			bounceAnimationRight.repeatCount = 0;
			bounceAnimationRight.autoreverses = YES;
			bounceAnimationRight.fillMode = kCAFillModeBackwards;
			bounceAnimationRight.removedOnCompletion = YES;
			bounceAnimationRight.additive = NO;
			[viewAtRight.layer addAnimation:bounceAnimationRight forKey:@"bounceAnimationRight"];
			
		}
		else if ([animationID isEqualToString:@"RIGHT-WITH-LEFT"]) 
		{
			CABasicAnimation *bounceAnimationLeft = [CABasicAnimation animationWithKeyPath:@"position"];
			bounceAnimationLeft.duration = BOUNCE_ANIMATION_DURATION;
			bounceAnimationLeft.fromValue = [NSValue valueWithCGPoint:viewAtLeft.center];
			bounceAnimationLeft.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtLeft.center.x +10, viewAtLeft.center.y)];
			bounceAnimationLeft.repeatCount = 0;
			bounceAnimationLeft.autoreverses = YES;
			bounceAnimationLeft.fillMode = kCAFillModeBackwards;
			bounceAnimationLeft.removedOnCompletion = YES;
			bounceAnimationLeft.additive = NO;
			[viewAtLeft.layer addAnimation:bounceAnimationLeft forKey:@"bounceAnimationLeft"];
			
			if (viewAtLeft2 != nil) 
			{
				viewAtLeft2.hidden = NO;
				NSInteger viewAtLeft2Position = [[slideViews subviews] indexOfObject:viewAtLeft2];
				if (viewAtLeft2Position > 0) 
				{
					[((UIView*)[[slideViews subviews] objectAtIndex:viewAtLeft2Position -1]) setHidden:NO];
				}
				CABasicAnimation* bounceAnimationLeft2 = [CABasicAnimation animationWithKeyPath:@"position"];
				bounceAnimationLeft2.duration = BOUNCE_ANIMATION_DURATION;
				bounceAnimationLeft2.fromValue = [NSValue valueWithCGPoint:viewAtLeft2.center];
				bounceAnimationLeft2.toValue = [NSValue valueWithCGPoint:CGPointMake(viewAtLeft2.center.x +10, viewAtLeft2.center.y)];
				bounceAnimationLeft2.repeatCount = 0;
				bounceAnimationLeft2.autoreverses = YES;
				bounceAnimationLeft2.fillMode = kCAFillModeBackwards;
				bounceAnimationLeft2.removedOnCompletion = YES;
				bounceAnimationLeft2.additive = NO;
				[viewAtLeft2.layer addAnimation:bounceAnimationLeft2 forKey:@"bounceAnimationviewAtLeft2"];
				[self performSelector:@selector(callArrangeVerticalBar) withObject:nil afterDelay:0.4];
				isBouncing = YES;
			}
		}
	}
	[self arrangeVerticalBar];	
	if ([[slideViews subviews] indexOfObject:viewAtLeft2] == 1 && isBouncing)
	{
		[[borderViews viewWithTag:2] setHidden:YES];
	}
}


- (void)callArrangeVerticalBar
{
	[self arrangeVerticalBar];
}

/*- (void)popTopViewController
{
	NSUInteger index = [viewControllersStack count]-1;
	UIView *viewToRemove = [self slideViewAtIndex:index];
	[viewToRemove removeFromSuperview];
	[viewControllersStack removeObjectAtIndex:index];
	viewXPosition = self.view.frame.size.width - [[viewControllersStack firstObjectSafe] view].frame.size.width;
}

- (void)popToRootViewController
{
	NSInteger viewControllerCount = [viewControllersStack count];
	for (int i = viewControllerCount - 1; i >= 1; i--)
	{
		UIView *viewToRemove = [self slideViewAtIndex:i];
		[viewToRemove removeFromSuperview];
		[viewControllersStack removeObjectAtIndex:i];
		viewXPosition = self.view.frame.size.width - [[viewControllersStack firstObjectSafe] view].frame.size.width;
	}
}*/

- (void)addViewInSlider:(UIViewController*)controller
{
	[self addViewInSlider:controller invokeByController:[self.viewControllersStack lastObject] isStackStartView:NO];
}

- (void)addViewInSlider:(UIViewController*)controller invokeByController:(UIViewController*)invokeByController isStackStartView:(BOOL)isStackStartView
{	
	if (isStackStartView) 
	{
		slideStartPosition = SLIDE_VIEWS_START_X_POS;
		viewXPosition = slideStartPosition;
		
		for (UIView* subview in [slideViews subviews])
		{
			[subview removeFromSuperview];
		}
		
		[[borderViews viewWithTag:3] setHidden:YES];
		[[borderViews viewWithTag:2] setHidden:YES];
		[[borderViews viewWithTag:1] setHidden:YES];
		[viewControllersStack removeAllObjects];
	}
	
	if([viewControllersStack count] > 1)
	{
		NSInteger indexOfViewController = [viewControllersStack
										   indexOfObject:invokeByController]+1;
		
		if ([invokeByController parentViewController]) 
		{
			indexOfViewController = [viewControllersStack
									 indexOfObject:[invokeByController parentViewController]]+1;
		}
		
		NSInteger viewControllerCount = [viewControllersStack count];
		for (int i = (int)(viewControllerCount - 1); i >= indexOfViewController; i--)
		{
			UIView *viewToRemove = [self slideViewAtIndex:i];
			[viewToRemove removeFromSuperview];
			[viewControllersStack removeObjectAtIndex:i];
			viewXPosition = self.view.frame.size.width - [controller view].frame.size.width;
		}
	}
	else if([viewControllersStack count] == 0) 
	{
		for (UIView* subview in [slideViews subviews]) 
		{
			[subview removeFromSuperview];
		}		
		[viewControllersStack removeAllObjects];
		[[borderViews viewWithTag:3] setHidden:YES];
		[[borderViews viewWithTag:2] setHidden:YES];
		[[borderViews viewWithTag:1] setHidden:YES];
	}
		
	// Create the container view -- necessary because the shadow layer does 
	// not draw correctly on UITableViewControllers for some reason
	StackContainerView *contView = [[StackContainerView alloc] initWithFrame:controller.view.frame];
	
	[viewControllersStack addObject:controller];
	if (invokeByController !=nil) 
	{
		viewXPosition = invokeByController.view.frame.origin.x + invokeByController.view.frame.size.width;			
	}
	if ([[slideViews subviews] count] == 0) 
	{
		slideStartPosition = SLIDE_VIEWS_START_X_POS;
		viewXPosition = slideStartPosition;
	}
	[[controller view] setFrame:CGRectMake(0, 0, [controller view].frame.size.width, self.view.frame.size.height)];
	
	[contView addSubview:controller.view];
	contView.x = viewXPosition;
	contView.tag = [viewControllersStack count] - 1;
	//[controller viewWillAppear:NO];
	//[controller viewDidAppear:NO];
	
	NSLog(@"  ");
	for (UIView *subView in [slideViews subviews])
	{
		NSLog(@"subView.tag: %li", (long)subView.tag);
	}
	NSLog(@"  ");
	
	[slideViews addSubview:contView];
	
	NSLog(@"  ");
	for (UIView *subView in [slideViews subviews])
	{
		NSLog(@"subView.tag: %li", (long)subView.tag);
	}
	NSLog(@"  ");
	
	if ([[slideViews subviews] count] > 0)
	{
		if ([[slideViews subviews] count]==1) 
		{
			viewAtLeft = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-1];
			viewAtLeft2 = nil;
			viewAtRight = nil;
			viewAtRight2 = nil;
		}
		else if ([[slideViews subviews] count]==2)
		{
			viewAtRight = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-1];
			viewAtLeft = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-2];
			viewAtLeft2 = nil;
			viewAtRight2 = nil;
			
			[UIView beginAnimations:nil context:NULL];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
			[UIView setAnimationBeginsFromCurrentState:NO];
			[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
			[viewAtRight setFrame:CGRectMake(self.view.frame.size.width - viewAtRight.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
			[UIView commitAnimations];
			slideStartPosition = SLIDE_VIEWS_MINUS_X_POSITION;
		}
		else 
		{
			
			if (((UIView*)[[slideViews subviews] objectAtIndex:0]).frame.origin.x > SLIDE_VIEWS_MINUS_X_POSITION)
			{
				UIView* tempRight2View =[[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-1];
				[UIView beginAnimations:@"ALIGN_TO_MINIMENU" context:NULL];
                [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
				[UIView setAnimationBeginsFromCurrentState:NO];
				[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
				[viewAtRight setFrame:CGRectMake(self.view.frame.size.width - viewAtRight.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
				[tempRight2View setFrame:CGRectMake(self.view.frame.size.width, tempRight2View.frame.origin.y, tempRight2View.frame.size.width, tempRight2View.frame.size.height)];
				[UIView setAnimationDelegate:self];
				[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
				[UIView commitAnimations];
			}
			else 
			{
				viewAtRight = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-1];
				viewAtLeft = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-2];
				viewAtLeft2 = [[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-3];
				[viewAtLeft2 setHidden:NO];
				viewAtRight2 = nil;
				
				[UIView beginAnimations:nil context:NULL];
                [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
				[UIView setAnimationBeginsFromCurrentState:NO];
				[viewAtLeft setFrame:CGRectMake(SLIDE_VIEWS_MINUS_X_POSITION, viewAtLeft.frame.origin.y, viewAtLeft.frame.size.width, viewAtLeft.frame.size.height)];
				[viewAtRight setFrame:CGRectMake(self.view.frame.size.width - viewAtRight.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
				[UIView setAnimationDelegate:self];
				[UIView setAnimationDidStopSelector:@selector(bounceBack:finished:context:)];
				[UIView commitAnimations];				
				slideStartPosition = SLIDE_VIEWS_MINUS_X_POSITION;	
				if([[slideViews subviews] count] > 3)
				{
					[[[slideViews subviews] objectAtIndex:[[slideViews subviews] count]-4] setHidden:YES];		
				}
			}
			
			
		}
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	for (UIViewController* subController in viewControllersStack) 
	{
		[subController viewDidUnload];
	}
}


#pragma mark - Rotation support

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	BOOL isViewOutOfScreen = NO; 
	/*for (UIViewController* subController in viewControllersStack)
	{
		if (viewAtRight != nil && [viewAtRight isEqual:subController.view]) 
		{
			if (viewAtRight.frame.origin.x + viewAtRight.frame.size.width <= self.view.frame.size.width) 
			{
				[subController.view setFrame:CGRectMake(self.view.frame.size.width - subController.view.frame.size.width, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
			}
			else
			{
				[subController.view setFrame:CGRectMake(viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
			}
			isViewOutOfScreen = YES;
		}
		else if (viewAtLeft != nil && [viewAtLeft isEqual:subController.view])
		{
			if (viewAtLeft2 == nil) 
			{
				if(viewAtRight == nil)
				{					
					[subController.view setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
				}
				else
				{
					[subController.view setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
					[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS + subController.view.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
				}
			}
			else if (viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION || viewAtLeft.frame.origin.x == SLIDE_VIEWS_START_X_POS) 
			{
				[subController.view setFrame:CGRectMake(subController.view.frame.origin.x, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
			}
			else 
			{
				if (viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width == self.view.frame.size.width) 
				{
					[subController.view setFrame:CGRectMake(self.view.frame.size.width - subController.view.frame.size.width, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
				}
				else
				{
					[subController.view setFrame:CGRectMake(viewAtLeft2.frame.origin.x + viewAtLeft2.frame.size.width, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
				}
			}
		}
		else if(!isViewOutOfScreen)
		{
			[subController.view setFrame:CGRectMake(subController.view.frame.origin.x, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
		}
		else
		{
			[subController.view setFrame:CGRectMake(self.view.frame.size.width, subController.view.frame.origin.y, subController.view.frame.size.width, self.view.frame.size.height)];
		}
		
	}
	for (UIViewController* subController in viewControllersStack) 
	{
		[subController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration]; 		
		if (!((viewAtRight != nil && [viewAtRight isEqual:subController.view]) 
			|| (viewAtLeft != nil && [viewAtLeft isEqual:subController.view]) 
			|| (viewAtLeft2 != nil && [viewAtLeft2 isEqual:subController.view]))) 
		{
			[[subController view] setHidden:YES];		
		}
		
	}       	*/
	
	for (StackContainerView *contView in slideViews.subviews)
	{
		if (viewAtRight != nil && [viewAtRight isEqual:contView]) 
		{
			if (viewAtRight.frame.origin.x + viewAtRight.frame.size.width <= self.view.frame.size.width) 
			{
				[contView setFrame:CGRectMake(self.view.frame.size.width - contView.frame.size.width, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
			}
			else
			{
				[contView setFrame:CGRectMake(viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
			}
			isViewOutOfScreen = YES;
		}
		else if (viewAtLeft != nil && [viewAtLeft isEqual:contView])
		{
			if (viewAtLeft2 == nil) 
			{
				if(viewAtRight == nil)
				{					
					[contView setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
				}
				else
				{
					[contView setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
					[viewAtRight setFrame:CGRectMake(SLIDE_VIEWS_START_X_POS + contView.frame.size.width, viewAtRight.frame.origin.y, viewAtRight.frame.size.width, viewAtRight.frame.size.height)];
				}
			}
			else if (viewAtLeft.frame.origin.x == SLIDE_VIEWS_MINUS_X_POSITION || viewAtLeft.frame.origin.x == SLIDE_VIEWS_START_X_POS) 
			{
				[contView setFrame:CGRectMake(contView.frame.origin.x, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
			}
			else 
			{
				if (viewAtLeft.frame.origin.x + viewAtLeft.frame.size.width == self.view.frame.size.width) 
				{
					[contView setFrame:CGRectMake(self.view.frame.size.width - contView.frame.size.width, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
				}
				else
				{
					[contView setFrame:CGRectMake(viewAtLeft2.frame.origin.x + viewAtLeft2.frame.size.width, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
				}
			}
		}
		else if(!isViewOutOfScreen)
		{
			[contView setFrame:CGRectMake(contView.frame.origin.x, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
		}
		else
		{
			[contView setFrame:CGRectMake(self.view.frame.size.width, contView.frame.origin.y, contView.frame.size.width, self.view.frame.size.height)];
		}
		contView.insideView.size = contView.size;
	}
	
	for (UIViewController* subController in viewControllersStack) 
	{
		[subController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
		/*if (!((viewAtRight != nil && [viewAtRight isEqual:subController.view]) 
			  || (viewAtLeft != nil && [viewAtLeft isEqual:subController.view]) 
			  || (viewAtLeft2 != nil && [viewAtLeft2 isEqual:subController.view]))) 
		{
			subController.view.hidden = YES;		
		}*/
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation 
{	
	for (UIViewController* subController in viewControllersStack)
	{
		[subController didRotateFromInterfaceOrientation:fromInterfaceOrientation];                
	}
	
	viewAtLeft.hidden = NO;
	viewAtRight.hidden = NO;
	viewAtLeft2.hidden = NO;
}



@end