//
//  EX2SlidingNotification.m
//  EX2Kit
//
//  Created by Ben Baron on 4/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIView+Tools.h"
#import "EX2SlidingNotification.h"
#import "NSArray+Additions.h"
#import "UIView+Tools.h"
#import "EX2Kit.h"

#define ANIMATION_DELAY 0.25
#define DEFAULT_DISPLAY_TIME 5.0

@interface EX2SlidingNotification()
@property (nonatomic, strong) EX2SlidingNotification *selfRef;
@end

@implementation EX2SlidingNotification

// Allow user to set the window explicitly
static __strong UIWindow *_mainWindow = nil;
+ (void)setMainWindow:(UIWindow *)mainWindow
{
    _mainWindow = mainWindow;
}

+ (UIWindow *)mainWindow
{
    return _mainWindow ? _mainWindow : [[UIApplication sharedApplication] keyWindow];
}

static __strong NSMutableArray *_activeMessages = nil;

+ (BOOL)showingMessage:(NSString *)message
{
    @synchronized(_activeMessages)
    {
        if (!_isThrottlingEnabled)
        {
            // Always display if throttling is not enabled
            return YES;
        }
        else if ([_activeMessages containsObject:message])
        {
            // Already showing, so return false to ignore this one
            return NO;
        }
        else
        {
            [_activeMessages addObject:message];
            return YES;
        }
    }
}

+ (void)hidingMessage:(NSString *)message
{
    @synchronized(_activeMessages)
    {
        [_activeMessages removeObject:message];
    }
}

static BOOL _isThrottlingEnabled = YES;
+ (BOOL)isThrottlingEnabled
{
    @synchronized(_activeMessages)
    {
        return _isThrottlingEnabled;
    }
}

+ (void)setIsThrottlingEnabled:(BOOL)throttlingEnabled
{
    @synchronized(_activeMessages)
    {
        _isThrottlingEnabled = throttlingEnabled;
    }
}

+ (void)initialize
{
    if (self == [EX2SlidingNotification class])
    {
        _activeMessages = [NSMutableArray arrayWithCapacity:0];
    }
}

- (id)initOnView:(UIView *)theParentView message:(NSString *)theMessage image:(UIImage*)theImage displayTime:(NSTimeInterval)time
{
	if ((self = [super initWithNibName:@"EX2SlidingNotification" bundle:[EX2Kit resourceBundle]])) 
	{
		_displayTime = time;
		_parentView = theParentView;
		_image = theImage;
		_message = [theMessage copy];
		
		// If we're directly on the UIWindow, add 20 points for the status bar
		self.view.frame = CGRectMake(0., 0, _parentView.width, self.view.height);
        if (IS_IOS7())
        {
            self.imageView.y += 15.;
            self.messageLabel.y += 15.;
        }
		
		[_parentView addSubview:self.view];
	}
	
	return self;
}

- (id)initOnView:(UIView *)theParentView message:(NSString *)theMessage image:(UIImage*)theImage
{
	return [self initOnView:theParentView message:theMessage image:theImage displayTime:DEFAULT_DISPLAY_TIME];
}

+ (id)slidingNotificationOnMainWindowWithMessage:(NSString *)theMessage image:(UIImage*)theImage
{
	return [[self alloc] initOnView:[self mainWindow] message:theMessage image:theImage];
}

+ (id)slidingNotificationOnTopViewWithMessage:(NSString *)theMessage image:(UIImage*)theImage
{
	return [[self alloc] initOnView:[self mainWindow].subviews.firstObjectSafe message:theMessage image:theImage];
}

+ (id)slidingNotificationOnView:(UIView *)theParentView message:(NSString *)theMessage image:(UIImage*)theImage
{
	return [[self alloc] initOnView:theParentView message:theMessage image:theImage];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.imageView.image = self.image;
	self.messageLabel.text = self.message;
	
	[self.view addBottomShadow];
	CALayer *shadow = [[self.view.layer sublayers] objectAtIndexSafe:0];
    shadow.frame = CGRectMake(shadow.frame.origin.x, shadow.frame.origin.y, 1024., shadow.frame.size.height);
    
    [self sizeToFit];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)sizeToFit
{
	CGSize maximumLabelSize = CGSizeMake(self.messageLabel.width, 300.);
	CGSize expectedLabelSize = [self.message sizeWithFont:self.messageLabel.font constrainedToSize:maximumLabelSize lineBreakMode:self.messageLabel.lineBreakMode];
	if (expectedLabelSize.height >= 25.)
	{
		self.messageLabel.size = expectedLabelSize;
		self.view.height = self.messageLabel.height + 6.;
		
		[[[self.view.layer sublayers] objectAtIndexSafe:0] removeFromSuperlayer];
		[self.view addBottomShadow];
		CALayer *shadow = [[self.view.layer sublayers] objectAtIndexSafe:0];
		shadow.frame = CGRectMake(shadow.frame.origin.x, shadow.frame.origin.y, 1024., shadow.frame.size.height);
	}
    
    // Add 20 points for the status bar if we're on iOS 7.
    if (IS_IOS7())
        self.view.height += 20.;
}

- (BOOL)showAndHideSlidingNotification
{
	if ([self showSlidingNotification])
    {
        [self performSelector:@selector(hideSlidingNotification) withObject:nil afterDelay:self.displayTime];
        
        return YES;
    }
	
	return NO;
}

- (BOOL)showAndHideSlidingNotification:(NSTimeInterval)showTime
{
    self.displayTime = showTime;
    
    return [self showAndHideSlidingNotification];
}

- (BOOL)showSlidingNotification
{
    if ([self.class showingMessage:self.message])
    {
        if (!self.selfRef)
            self.selfRef = self;
        
        // Set the start position
        self.view.y = -self.view.height;
        if (self.view.superview == [self.class mainWindow])
            self.view.y += [[UIApplication sharedApplication] statusBarFrame].size.height;
        
        //DLog(@"current frame: %@", NSStringFromCGRect(self.view.frame));
        [UIView animateWithDuration:ANIMATION_DELAY animations:^(void)
         {
             // If we're directly on the UIWindow then add the status bar height
             CGFloat y = 0.;
             if (self.view.superview == [self.class mainWindow] && !IS_IOS7())
                 y = [[UIApplication sharedApplication] statusBarFrame].size.height;
             
             self.view.y = y;
             
             //DLog(@"new frame: %@", NSStringFromCGRect(self.view.frame));
         }];
        
        return YES;
    }
	
    // Remove the view since it won't be displayed
    [self.view removeFromSuperview];
    return NO;
}

- (void)hideSlidingNotification
{
    [self.class hidingMessage:self.message];
    
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
	
	[UIView animateWithDuration:ANIMATION_DELAY animations:^(void)
     {
         self.view.y = -self.view.height;
     }
    completion:^(BOOL finished)
     {
         [self.view removeFromSuperview];
         self.selfRef = nil;
     }];
}

- (IBAction)buttonAction:(id)sender
{
    if (self.tapBlock)
    {
        self.tapBlock();
    }
}

@end
