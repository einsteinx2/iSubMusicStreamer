//
//  CustomUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 12/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"
#import "CellOverlay.h"

@implementation CustomUITableViewCell
@synthesize isOverlayShowing, overlayView, isIndexShowing, indexPath, isSearching, deleteToggleImage, isDelete;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) 
	{
        isIndexShowing = NO;
		isOverlayShowing = NO;
		overlayView = nil;
		indexPath = nil;
		isSearching = NO;
		isDelete = NO;
		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		deleteToggleImage.hidden = YES;
    }
    return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGRect oldFrame = self.deleteToggleImage.frame;
	CGFloat newY = (self.frame.size.height / 2.) - (oldFrame.size.height / 2.);
	self.deleteToggleImage.frame = CGRectMake(5.0, newY, oldFrame.size.width, oldFrame.size.height);
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	//if (viewObjectsS.isEditing)
		[super setEditing:editing animated:animated]; 
}

- (void)showOverlay
{
	if (!self.isOverlayShowing)
	{
		self.overlayView = [CellOverlay cellOverlayWithTableCell:self];
		[self.contentView addSubview:self.overlayView];
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		self.overlayView.alpha = 1.0;
		[UIView commitAnimations];		
		
		self.isOverlayShowing = YES;
	}
}

- (void)hideOverlay
{
	if (self.overlayView)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(overlayHidden)];
		self.overlayView.alpha = 0.0;
		[UIView commitAnimations];
		
		self.isOverlayShowing = NO;
	}
}

- (void)overlayHidden
{
	if (!self.isOverlayShowing)
	{
		[self.overlayView removeFromSuperview];
		self.overlayView = nil;
	}	
}

- (void)downloadAction
{
	return;
}

- (void)queueAction
{
	return;
}

- (void)blockerAction
{
	[self hideOverlay];
}

- (void)scrollLabels
{
	return;
}

- (void)toggleDelete
{
	if (self.isDelete)
	{
		[viewObjectsS.multiDeleteList removeObject:@(indexPath.row)];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
	else
	{
		[viewObjectsS.multiDeleteList addObject:@(indexPath.row)];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	self.isDelete = !self.isDelete;
}

- (UIImage *)nowPlayingImageBlack
{
	return [UIImage imageNamed:@"playing-cell-icon.png"];
}

- (UIImage *)nowPlayingImageWhite
{
	return [UIImage imageNamed:@"playing-cell-icon-white.png"];
}

@end
