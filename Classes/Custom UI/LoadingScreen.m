//
//  LoadingScreen.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LoadingScreen.h"

@implementation LoadingScreen

- (id)initOnView:(UIView *)superView withMessage:(NSArray *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow
{
	//[self showLoadingScreen:view withMessage:message blockInput:blockInput mainWindow:mainWindow];
	
	if (self = (LoadingScreen *)[super initWithNibName:@"LoadingScreen" bundle:nil])
	{
		[superView addSubview:self.view];
		self.view.center = CGPointMake(superView.bounds.size.width / 2, superView.bounds.size.height / 2);
				
		/*self.activityIndicator.frame = CGRectMake(20, 10, 30, 30);
		
		self.loadingScreenRectangle = [[UIImageView alloc] init];
		self.loadingScreenRectangle.frame = CGRectMake(40, 96, 240, 180);
		//self.loadingScreenRectangle.center = CGPointMake(superView.bounds.size.width / 2, superView.bounds.size.height / 2);
		
		self.loadingScreenRectangle.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.loadingScreenRectangle.alpha = .80;
		[self.view addSubview:self.loadingScreenRectangle];
		[self.view sendSubviewToBack:self.loadingScreenRectangle];
		[self.loadingScreenRectangle release];*/
		
		if (mainWindow)
		{
			//DLog(@"mainWindow");
			CGRect frame = self.loadingScreenRectangle.frame;
			frame.origin.y -= 40;
			_loadingScreenRectangle.frame = frame;
			
			frame = _loadingLabel.frame;
			frame.origin.y -= 40;
			_loadingLabel.frame = frame;
			
			frame = _loadingTitle1.frame;
			frame.origin.y -= 40;
			_loadingTitle1.frame = frame;
			
			frame = _loadingMessage1.frame;
			frame.origin.y -= 40;
			_loadingMessage1.frame = frame;
			
			frame = _loadingTitle2.frame;
			frame.origin.y -= 40;
			_loadingTitle2.frame = frame;
			
			frame = _loadingMessage2.frame;
			frame.origin.y -= 40;
			_loadingMessage2.frame = frame;
			
			frame = _activityIndicator.frame;
			frame.origin.y -= 40;
			_activityIndicator.frame = frame;
		}
		
		if (message)
		{
			if ([message count] == 4)
			{
				_loadingTitle1.text = [message objectAtIndexSafe:0];
				_loadingMessage1.text = [message objectAtIndexSafe:1];
				_loadingTitle2.text = [message objectAtIndexSafe:2];
				_loadingMessage2.text = [message objectAtIndexSafe:3];
			}
			else
			{
				_loadingTitle1.text = @"";
				_loadingMessage1.text = @"";
				_loadingTitle2.text = @"";
				_loadingMessage2.text = @"";
			}
		}
		else 
		{
			_loadingTitle1.text = @"";
            _loadingMessage1.text = @"";
			_loadingTitle2.text = @"";
			_loadingMessage2.text = @"";
		}
	}
	return self;
}

- (IBAction)inputBlockerAction:(id)sender
{
	//DLog(@"INPUT BLOOOOOOOOOCKER!!!!!!");
}


- (void)setAllMessagesText:(NSArray *)messages
{
	if ([messages count] == 4)
	{
		self.loadingTitle1.text = [messages objectAtIndexSafe:0];
		self.loadingMessage1.text = [messages objectAtIndexSafe:1];
		self.loadingTitle2.text = [messages objectAtIndexSafe:2];
		self.loadingMessage2.text = [messages objectAtIndexSafe:3];
	}
	else
	{
		self.loadingTitle1.text = @"";
		self.loadingMessage1.text = @"";
		self.loadingTitle2.text = @"";
		self.loadingMessage2.text = @"";
	}	
}


- (void)setMessage1Text:(NSString *)message
{
	self.loadingMessage1.text = message;
}


- (void)setMessage2Text:(NSString *)message
{
	self.loadingMessage2.text = message;
}


/*- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow
{
	inputBlocker = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	inputBlocker.frame = CGRectMake(0, 0, 320, 480);
	inputBlocker.enabled = blockInput;
	
	loadingScreenRectangle = [[UIImageView alloc] init];
	if (mainWindow)
		loadingScreenRectangle.frame = CGRectMake(40, 140, 240, 180);
	else
		loadingScreenRectangle.frame = CGRectMake(40, 100, 240, 180);
	loadingScreenRectangle.image = [UIImage imageNamed:@"loading-screen-image.png"];
	loadingScreenRectangle.alpha = .80;
	
	loadingLabel = [[UILabel alloc] init];
	loadingLabel.backgroundColor = [UIColor clearColor];
	loadingLabel.textColor = [UIColor whiteColor];
	loadingLabel.font = ISMSBoldFont(30);
	loadingLabel.textAlignment = NSTextAlignmentCenter;
	[loadingLabel setText:@"Loading"];
	loadingLabel.frame = CGRectMake(10, 15, 220, 50);
	[loadingScreenRectangle addSubview:loadingLabel];
	[loadingLabel release];
	
	loadingMessage = [[UILabel alloc] init];
	loadingMessage.backgroundColor = [UIColor clearColor];
	loadingMessage.textColor = [UIColor whiteColor];
	//loadingMessage.font = ISMSRegularFont(20);
	loadingMessage.font = ISMSRegularFont(18);
	loadingMessage.numberOfLines = 0;
	loadingMessage.textAlignment = NSTextAlignmentCenter;
	loadingMessage.adjustsFontSizeToFitWidth = YES;
	loadingMessage.minimumFontSize = 12;
	if (message)
		loadingMessage.text = message;
	else
		loadingMessage.text = @"";
	//loadingMessage.frame = CGRectMake(10, 57, 220, 70);
	loadingMessage.frame = CGRectMake(10, 57, 220, 110);
	[loadingScreenRectangle addSubview:loadingMessage];
	[loadingMessage release];
	
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicator.frame = CGRectMake(100, 130, 40, 40);
	//[loadingScreenRectangle addSubview:activityIndicator];
	//[activityIndicator startAnimating];
	[activityIndicator release];
	
	[view addSubview:loadingScreenRectangle];
	[view addSubview:inputBlocker];
	
	[loadingScreenRectangle release];
	[inputBlocker release];
}*/

- (void)hide
{
	//[loadingScreenRectangle removeFromSuperview];
	//[inputBlocker removeFromSuperview];
	[self.view removeFromSuperview];
}



@end
