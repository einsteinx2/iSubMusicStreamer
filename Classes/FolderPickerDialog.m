//
//  DDSocialDialog.m
//
//  Created by digdog on 6/6/10.
//  Copyright 2010 Ching-Lan 'digdog' HUANG and digdog software. All rights reserved.
//  http://digdog.tumblr.com
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//   
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//   
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/*
 * Copyright 2009 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FolderPickerDialog.h"
#import "ShuffleFolderPickerViewController.h"

static CGFloat kDDSocialDialogBorderWidth = 10;
static CGFloat kDDSocialDialogTransitionDuration = 0.3;
static CGFloat kDDSocialDialogTitleMarginX = 8.0;
static CGFloat kDDSocialDialogTitleMarginY = 4.0;
static CGFloat kDDSocialDialogPadding = 10;

@interface FolderPickerDialog () 
- (void)postDismissCleanup;

- (void)addRoundedRectToPath:(CGContextRef)context rect:(CGRect)rect radius:(float)radius;
- (void)drawRect:(CGRect)rect fill:(CGColorRef)fillColor radius:(CGFloat)radius;
- (void)strokeLines:(CGRect)rect stroke:(CGColorRef)strokeColor;

- (void)bounce1AnimationStopped;
- (void)bounce2AnimationStopped;
- (CGAffineTransform)transformForOrientation;
- (void)sizeToFitOrientation:(BOOL)transform;
- (BOOL)shouldRotateToOrientation:(UIDeviceOrientation)orientation;

- (void)deviceOrientationDidChange:(void*)object;
- (void)keyboardDidShow:(NSNotification*)notification;
- (void)keyboardWillHide:(NSNotification*)notification;
@end

@implementation FolderPickerDialog

@synthesize titleLabel = titleLabel_;
@synthesize folderPicker = folderPicker_;

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:CGRectZero])) 
	{
        // Initialization code
		defaultFrameSize_ = frame.size;
		
		self.backgroundColor = [UIColor clearColor];
		self.autoresizesSubviews = YES;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.contentMode = UIViewContentModeRedraw;
		
		UIColor* color = [UIColor colorWithRed:167.0/255 green:184.0/255 blue:216.0/255 alpha:1];
		closeButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
		[closeButton_ setTitle:@"X" forState:UIControlStateNormal];
		[closeButton_ setTitleColor:color forState:UIControlStateNormal];
		[closeButton_ setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[closeButton_ addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
		closeButton_.titleLabel.font = ISMSBoldFont(18);
		closeButton_.showsTouchWhenHighlighted = YES;
		closeButton_.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
		[self addSubview:closeButton_];
		
		CGFloat titleLabelFontSize = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 18 : 14;
		titleLabel_ = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel_.text = NSStringFromClass([self class]);
		titleLabel_.backgroundColor = [UIColor clearColor];
		titleLabel_.textColor = [UIColor whiteColor];
		//titleLabel_.textColor = [UIColor blackColor];
		titleLabel_.font = ISMSBoldFont(titleLabelFontSize);
		titleLabel_.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		[self addSubview:titleLabel_];
		
		folderPicker_ = [[ShuffleFolderPickerViewController alloc] initWithNibName:@"ShuffleFolderPickerViewController" bundle:nil];
		folderPicker_.view.frame = CGRectZero;
		//folderPicker_.view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
		folderPicker_.view.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.8];
		folderPicker_.myDialog = self;
		folderPicker_.view.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		folderPicker_.view.contentMode = UIViewContentModeRedraw;
		[self addSubview:folderPicker_.view];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
	UIColor *DDSocialDialogTitleBackgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
	//UIColor *DDSocialDialogTitleStrokeColor = [UIColor colorWithRed:0.753 green:0.341 blue:0.145 alpha:1.0];
	UIColor *DDSocialDialogTitleStrokeColor = [UIColor colorWithWhite:0.0 alpha:1.0];
	//UIColor *DDSocialDialogBlackStrokeColor = [UIColor colorWithRed:0.753 green:0.341 blue:0.145 alpha:1.0];
	UIColor *DDSocialDialogBlackStrokeColor = [UIColor colorWithWhite:0.0 alpha:1.0];
	UIColor *DDSocialDialogBorderColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8];
	//UIColor *DDSocialDialogBorderColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.8];
	
	CGRect grayRect = CGRectOffset(rect, -0.5, -0.5);
	[self drawRect:grayRect fill:DDSocialDialogBorderColor.CGColor radius:10];
	
	CGRect headerRect = CGRectIntegral(CGRectMake(rect.origin.x + kDDSocialDialogBorderWidth, rect.origin.y + kDDSocialDialogBorderWidth, rect.size.width - kDDSocialDialogBorderWidth*2, titleLabel_.frame.size.height));
	[self drawRect:headerRect fill:DDSocialDialogTitleBackgroundColor.CGColor radius:0];
	[self strokeLines:headerRect stroke:DDSocialDialogTitleStrokeColor.CGColor];
	
	CGRect contentRect = CGRectIntegral(CGRectMake(rect.origin.x + kDDSocialDialogBorderWidth, headerRect.origin.y + headerRect.size.height, rect.size.width - kDDSocialDialogBorderWidth*2, folderPicker_.view.frame.size.height+1));
	[self strokeLines:contentRect stroke:DDSocialDialogBlackStrokeColor.CGColor];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	closeButton_ = nil;
	titleLabel_ = nil;
	touchInterceptingControl_ = nil;
}

#pragma mark -

- (void)show {
	
	[self sizeToFitOrientation:NO];
	
	CGFloat innerWidth = self.frame.size.width - (kDDSocialDialogBorderWidth+1)*2;  
	[titleLabel_ sizeToFit];
	[closeButton_ sizeToFit];
	
	titleLabel_.frame = CGRectMake(kDDSocialDialogBorderWidth + kDDSocialDialogTitleMarginX,
								   kDDSocialDialogBorderWidth,
								   innerWidth - (titleLabel_.frame.size.height + kDDSocialDialogTitleMarginX*2),
								   titleLabel_.frame.size.height + kDDSocialDialogTitleMarginY*2);
	
	closeButton_.frame = CGRectMake(self.frame.size.width - (titleLabel_.frame.size.height + kDDSocialDialogBorderWidth),
									kDDSocialDialogBorderWidth,
									titleLabel_.frame.size.height,
									titleLabel_.frame.size.height);
	
	folderPicker_.view.frame = CGRectMake(kDDSocialDialogBorderWidth+1,
									kDDSocialDialogBorderWidth + titleLabel_.frame.size.height,
									innerWidth,
									self.frame.size.height - (titleLabel_.frame.size.height + 1 + kDDSocialDialogBorderWidth*2));
	
	UIWindow* window = [UIApplication sharedApplication].keyWindow;
	if (!window) {
		window = [[UIApplication sharedApplication].windows objectAtIndexSafe:0];
	}
	
	// Touch background to dismiss dialog
	touchInterceptingControl_ = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
	touchInterceptingControl_.userInteractionEnabled = YES;
	[window addSubview:touchInterceptingControl_];
	
	[window addSubview:self];
	
	self.transform = CGAffineTransformScale([self transformForOrientation], 0.001, 0.001);
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:kDDSocialDialogTransitionDuration/1.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(bounce1AnimationStopped)];
	self.transform = CGAffineTransformScale([self transformForOrientation], 1.1, 1.1);
	[UIView commitAnimations];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(deviceOrientationDidChange:)
												 name:@"UIDeviceOrientationDidChangeNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardDidShow:) name:@"UIKeyboardDidShowNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:) name:@"UIKeyboardWillHideNotification" object:nil];	
}

- (void)cancel:(id)sender
{
	[self dismiss:YES];
}

- (void)dismiss:(BOOL)animated {
	
	if (animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:kDDSocialDialogTransitionDuration];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(postDismissCleanup)];
		self.alpha = 0;
		[UIView commitAnimations];
	} else {
		[self postDismissCleanup];
	}
}

- (void)postDismissCleanup {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"UIDeviceOrientationDidChangeNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"UIKeyboardDidShowNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"UIKeyboardWillHideNotification" object:nil];
	[self removeFromSuperview];
	[touchInterceptingControl_ removeFromSuperview];
}

#pragma mark -
#pragma mark Drawing

- (void)addRoundedRectToPath:(CGContextRef)context rect:(CGRect)rect radius:(float)radius {
	
	CGContextBeginPath(context);
	CGContextSaveGState(context);
	
	if (radius == 0) {
		CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
		CGContextAddRect(context, rect);
	} else {
		rect = CGRectOffset(CGRectInset(rect, 0.5, 0.5), 0.5, 0.5);
		CGContextTranslateCTM(context, CGRectGetMinX(rect)-0.5, CGRectGetMinY(rect)-0.5);
		CGContextScaleCTM(context, radius, radius);
		float fw = CGRectGetWidth(rect) / radius;
		float fh = CGRectGetHeight(rect) / radius;
		
		CGContextMoveToPoint(context, fw, fh/2);
		CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
		CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
		CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
		CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
	}
	
	CGContextClosePath(context);
	CGContextRestoreGState(context);
}

- (void)drawRect:(CGRect)rect fill:(CGColorRef)fillColor radius:(CGFloat)radius {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	
	if (fillColor) {
		CGContextSaveGState(context);
		CGContextSetFillColor(context, CGColorGetComponents(fillColor));
		if (radius) {
			[self addRoundedRectToPath:context rect:rect radius:radius];
			CGContextFillPath(context);
		} else {
			CGContextFillRect(context, rect);
		}
		CGContextRestoreGState(context);
	}
	
	CGColorSpaceRelease(space);
}

- (void)strokeLines:(CGRect)rect stroke:(CGColorRef)strokeColor {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	
	CGContextSaveGState(context);
	CGContextSetStrokeColorSpace(context, space);
	CGContextSetStrokeColor(context, CGColorGetComponents(strokeColor));
	CGContextSetLineWidth(context, 1.0);
    
	{
		CGPoint points[] = {rect.origin.x+0.5, rect.origin.y-0.5,
			rect.origin.x+rect.size.width, rect.origin.y-0.5};
		CGContextStrokeLineSegments(context, points, 2);
	}
	{
		CGPoint points[] = {rect.origin.x+0.5, rect.origin.y+rect.size.height-0.5,
			rect.origin.x+rect.size.width-0.5, rect.origin.y+rect.size.height-0.5};
		CGContextStrokeLineSegments(context, points, 2);
	}
	{
		CGPoint points[] = {rect.origin.x+rect.size.width-0.5, rect.origin.y,
			rect.origin.x+rect.size.width-0.5, rect.origin.y+rect.size.height};
		CGContextStrokeLineSegments(context, points, 2);
	}
	{
		CGPoint points[] = {rect.origin.x+0.5, rect.origin.y,
			rect.origin.x+0.5, rect.origin.y+rect.size.height};
		CGContextStrokeLineSegments(context, points, 2);
	}
	
	CGContextRestoreGState(context);
	
	CGColorSpaceRelease(space);
}

#pragma mark Animation

- (void)bounce1AnimationStopped {
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:kDDSocialDialogTransitionDuration/2];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(bounce2AnimationStopped)];
	self.transform = CGAffineTransformScale([self transformForOrientation], 0.9, 0.9);
	[UIView commitAnimations];
}

- (void)bounce2AnimationStopped {
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:kDDSocialDialogTransitionDuration/2];
	self.transform = [self transformForOrientation];
	[UIView commitAnimations];
}

#pragma mark Rotation

- (CGAffineTransform)transformForOrientation {
	
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (orientation == UIInterfaceOrientationLandscapeLeft) {
		return CGAffineTransformMakeRotation(M_PI*1.5);
	} else if (orientation == UIInterfaceOrientationLandscapeRight) {
		return CGAffineTransformMakeRotation(M_PI/2);
	} else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
		return CGAffineTransformMakeRotation(-M_PI);
	} else {
		return CGAffineTransformIdentity;
	}
}

- (void)sizeToFitOrientation:(BOOL)transform {
	
	if (transform) {
		self.transform = CGAffineTransformIdentity;
	}
	
	orientation_ = (UIDeviceOrientation)[UIApplication sharedApplication].statusBarOrientation;
	
	CGSize frameSize = defaultFrameSize_;
	self.frame = CGRectMake(kDDSocialDialogPadding, kDDSocialDialogPadding, frameSize.width - kDDSocialDialogPadding * 2, frameSize.height - kDDSocialDialogPadding * 2);
	
	if (!showingKeyboard_) {
		CGSize screenSize = [UIScreen mainScreen].bounds.size;
		CGPoint center = CGPointMake(ceil(screenSize.width/2), ceil(screenSize.height/2));
		self.center = center;		
	}
	
	if (transform) {
		self.transform = [self transformForOrientation];
	}
}

- (BOOL)shouldRotateToOrientation:(UIDeviceOrientation)orientation {
	
	if (orientation == orientation_) {
		return NO;
	} else {
		return orientation == UIDeviceOrientationLandscapeLeft
			|| orientation == UIDeviceOrientationLandscapeRight
			|| orientation == UIDeviceOrientationPortrait
			|| orientation == UIDeviceOrientationPortraitUpsideDown;
	}
}

#pragma mark Notifications

- (void)deviceOrientationDidChange:(void*)object {
	
	UIDeviceOrientation orientation = (UIDeviceOrientation)[UIApplication sharedApplication].statusBarOrientation;
	
	if ([self shouldRotateToOrientation:orientation]) {
		if (!showingKeyboard_) {
			if (UIDeviceOrientationIsLandscape(orientation)) {
				folderPicker_.view.frame = CGRectMake(kDDSocialDialogBorderWidth + 1,
												kDDSocialDialogBorderWidth + titleLabel_.frame.size.height,
												self.frame.size.width - (kDDSocialDialogBorderWidth+1)*2,
												self.frame.size.height - (titleLabel_.frame.size.height + 1 + kDDSocialDialogBorderWidth*2));
			} else {
				folderPicker_.view.frame = CGRectMake(kDDSocialDialogBorderWidth + 1,
												kDDSocialDialogBorderWidth + titleLabel_.frame.size.height,
												self.frame.size.height - (kDDSocialDialogBorderWidth+1)*2,
												self.frame.size.width - (titleLabel_.frame.size.height + 1 + kDDSocialDialogBorderWidth*2));
			}
		} 
		
		CGFloat duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:duration];
		[self sizeToFitOrientation:YES];
		[UIView commitAnimations];		
	}	
}

- (void)keyboardDidShow:(NSNotification*)notification {

	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;	

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && UIInterfaceOrientationIsPortrait(orientation)) {
		// On the iPad the screen is large enough that we don't need to 
		// resize the dialog to accomodate the keyboard popping up
		return;
	}

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	CGSize keyboardSize = [self convertRect:[[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] toView:nil].size;
	
	CGFloat duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:duration];
	switch (orientation) {
		case UIInterfaceOrientationPortrait:
			self.center = CGPointMake(self.center.x, ceil((screenSize.height - keyboardSize.height)/2) + 10.);
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			self.center = CGPointMake(self.center.x, screenSize.height - (ceil((screenSize.height - keyboardSize.height)/2) + 10.));
			break;
		case UIInterfaceOrientationLandscapeLeft:
			self.center = CGPointMake(ceil((screenSize.width - keyboardSize.height)/2), self.center.y);
			break;
		case UIInterfaceOrientationLandscapeRight:
			self.center = CGPointMake(screenSize.width - (ceil((screenSize.width - keyboardSize.height)/2)), self.center.y);
			break;
        case UIInterfaceOrientationUnknown:
            break;
	}	
	[UIView commitAnimations];
	
	showingKeyboard_ = YES;
}

- (void)keyboardWillHide:(NSNotification*)notification {

	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;	
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && UIInterfaceOrientationIsPortrait(orientation)) {
		return;
	}
	
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	
	CGFloat duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:duration];
	self.center = CGPointMake(ceil(screenSize.width/2), ceil(screenSize.height/2));
	[UIView commitAnimations];
	
	showingKeyboard_ = NO;
}

@end
