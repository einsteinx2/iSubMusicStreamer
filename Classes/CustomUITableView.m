//
//  CustomUITableView.m
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableView.h"
#import "CustomUITableViewCell.h"
#import "CellOverlay.h"

#define ISMSHorizSwipeDragMin 3
#define ISMSVertSwipeDragMax 80

#define ISMSCellEnableDelay 1.0
#define ISMSTapAndHoldDelay 0.25

@implementation CustomUITableView

@synthesize lastDeleteToggle, startTouchPosition, hasSwiped, cellShowingOverlay, tapAndHoldCell;

#pragma mark Lifecycle

- (void)setup
{
	lastDeleteToggle = [NSDate date];
    self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    if (IS_IOS7())
    {
        self.sectionIndexBackgroundColor = [UIColor clearColor];        
    }
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) 
	{		
		[self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		[self setup];
	}
	return self;
}

#pragma mark Touch gestures interception

- (void)hideAllOverlays:(UITableViewCell *)cellToSkip
{
	// Remove any visible buttons
	for (UITableViewCell *cell in self.visibleCells) 
	{
		if (cell != cellToSkip)
		{
			if ([cell isKindOfClass:[CustomUITableViewCell class]])
			{
				[(CustomUITableViewCell *)cell hideOverlay];
			}
		}
	}
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{	
	// Don't try anything when the tableview is moving
	// and do not catch as a swipe if touch is far right (potential index control)
	if (!self.decelerating && point.x < 290)
	{
		// Find the cell
		UITableViewCell *cell = [self cellForRowAtIndexPath:[self indexPathForRowAtPoint:point]];
		
		// Handle multi delete touching
		if (self.editing &&
			point.x < 40. && [[NSDate date] timeIntervalSinceDate:self.lastDeleteToggle] > 0.25)
		{
			self.lastDeleteToggle = [NSDate date];
			if ([cell isKindOfClass:[CustomUITableViewCell class]])
			{
				[(CustomUITableViewCell *)cell toggleDelete];
			}
		}
		
		// Remove overlays
		if (!self.hasSwiped)
		{			
			[self hideAllOverlays:cell];
			
			if ([cell isKindOfClass:[CustomUITableViewCell class]])
			{
				if ([(CustomUITableViewCell *)cell isOverlayShowing])
					[cell performSelector:@selector(hideOverlay) withObject:nil afterDelay:1.0];
			}
			
		}
	}
	//return nil;
	return [super hitTest:point withEvent:event];
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view 
{
	return YES;
}

- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view 
{
	return YES;
}

#pragma mark Touch gestures for custom cell view

- (void)disableCellsTemporarily
{
	self.allowsSelection = NO;
	[self performSelector:@selector(enableCells) withObject:nil afterDelay:ISMSCellEnableDelay];
}

- (void)enableCells
{
	self.allowsSelection = YES;
}

- (BOOL)isTouchHorizontal:(UITouch *)touch 
{
    CGPoint currentTouchPosition = [touch locationInView:self];
    CGFloat xMovement = fabs(startTouchPosition.x - currentTouchPosition.x);
    CGFloat yMovement = fabs(startTouchPosition.y - currentTouchPosition.y);
    NSLog(@"xMovement: %f  yMovement: %f", xMovement, yMovement);
    
	return xMovement > yMovement;
}

- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event 
{
    CGPoint currentTouchPosition = [[touches anyObject] locationInView:self];
	UITableViewCell *cell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:currentTouchPosition]];
	
	if (!self.hasSwiped) 
	{
		// Check if this is a full swipe
		if (fabs(self.startTouchPosition.x - currentTouchPosition.x) >= ISMSHorizSwipeDragMin
			&& fabs(self.startTouchPosition.y - currentTouchPosition.y) <= ISMSVertSwipeDragMax)
		{			
			self.hasSwiped = YES;
			self.scrollEnabled = NO;			
			
			// Temporarily disable the cells so we don't get accidental selections
			[self disableCellsTemporarily];
			
			// Hide any open overlays
			[self hideAllOverlays:nil];
			
			// Detect the direction
			if (self.startTouchPosition.x < currentTouchPosition.x) 
			{
				// Right swipe
				if (settingsS.isSwipeEnabled && !IS_IPAD())
				{
					if ([cell isKindOfClass:[CustomUITableViewCell class]])
					{
						[(CustomUITableViewCell *)cell showOverlay];
					}
					self.cellShowingOverlay = cell;
				}
			} 
			else 
			{
				// Left Swipe
				if ([cell isKindOfClass:[CustomUITableViewCell class]])
				{
					[(CustomUITableViewCell *)cell scrollLabels];
				}
			}
		} 
		else 
		{
			// Process a non-swipe event.
		}
	}
}

- (void)tapAndHoldFired
{
    self.hasSwiped = YES;
	if ([self.tapAndHoldCell isKindOfClass:[CustomUITableViewCell class]])
	{
		[(CustomUITableViewCell *)self.tapAndHoldCell showOverlay];
	}
	self.cellShowingOverlay = self.tapAndHoldCell;
}

- (void)cancelTapAndHold
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapAndHoldFired) object:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	self.allowsSelection = NO;
	self.scrollEnabled = YES;
		
	// Handle swipe
    self.startTouchPosition = [[touches anyObject] locationInView:self];
	self.hasSwiped = NO;
	self.cellShowingOverlay = nil;

	// Handle tap and hold
	if (settingsS.isTapAndHoldEnabled)
	{
		self.tapAndHoldCell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:self.startTouchPosition]];
		[self performSelector:@selector(tapAndHoldFired) withObject:nil afterDelay:ISMSTapAndHoldDelay];
	}
	
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	// Cancel the tap and hold if user moves finger
	[self cancelTapAndHold];
	
	// Check for swipe
	if ([self isTouchHorizontal:[touches anyObject]]) 
	{
		[self lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event];
	} 
	
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	self.allowsSelection = YES;
	self.scrollEnabled = YES;
	
	[self cancelTapAndHold];

	if (self.hasSwiped)
	{
		// Enable the buttons if the overlay is showing
		if ([self.cellShowingOverlay isKindOfClass:[CustomUITableViewCell class]])
		{
			[[(CustomUITableViewCell *)self.cellShowingOverlay overlayView] enableButtons];
		}
	}
	else
	{
		// Select the cell if this was a touch not a swipe or tap and hold
		CGPoint currentTouchPosition = [[touches anyObject] locationInView:self];
		if ((self.editing && currentTouchPosition.x > 40.) || !self.editing)
		{
			UITableViewCell *cell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:currentTouchPosition]];
			[self selectRowAtIndexPath:[self indexPathForCell:cell] animated:NO scrollPosition:UITableViewScrollPositionNone];
			[self.delegate tableView:self didSelectRowAtIndexPath:[self indexPathForCell:cell]];
		}
	}
	self.hasSwiped = NO;
		
	[super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self cancelTapAndHold];
	
	self.allowsSelection = YES;
	self.scrollEnabled = YES;
	self.hasSwiped = NO;
	
	if ([self.cellShowingOverlay isKindOfClass:[CustomUITableViewCell class]])
	{
		[[(CustomUITableViewCell *)self.cellShowingOverlay overlayView] enableButtons];
	}
		
	[super touchesCancelled:touches withEvent:event];
}


@end
