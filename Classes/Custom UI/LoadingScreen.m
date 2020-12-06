//
//  LoadingScreen.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LoadingScreen.h"
#import "EX2Kit.h"

@implementation LoadingScreen

- (instancetype)initOnView:(UIView *)superView withMessage:(NSArray *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow {
	if (self = (LoadingScreen *)[super initWithNibName:@"LoadingScreen" bundle:nil]) {
		[superView addSubview:self.view];
		self.view.center = CGPointMake(superView.bounds.size.width / 2, superView.bounds.size.height / 2);
		
		if (mainWindow) {
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
		
		if (message) {
			if (message.count == 4) {
				_loadingTitle1.text = [message objectAtIndexSafe:0];
				_loadingMessage1.text = [message objectAtIndexSafe:1];
				_loadingTitle2.text = [message objectAtIndexSafe:2];
				_loadingMessage2.text = [message objectAtIndexSafe:3];
			} else {
				_loadingTitle1.text = @"";
				_loadingMessage1.text = @"";
				_loadingTitle2.text = @"";
				_loadingMessage2.text = @"";
			}
		} else {
			_loadingTitle1.text = @"";
            _loadingMessage1.text = @"";
			_loadingTitle2.text = @"";
			_loadingMessage2.text = @"";
		}
	}
	return self;
}

- (IBAction)inputBlockerAction:(id)sender {
	//DLog(@"INPUT BLOOOOOOOOOCKER!!!!!!");
}

- (void)setAllMessagesText:(NSArray *)messages {
	if (messages.count == 4) {
		self.loadingTitle1.text = [messages objectAtIndexSafe:0];
		self.loadingMessage1.text = [messages objectAtIndexSafe:1];
		self.loadingTitle2.text = [messages objectAtIndexSafe:2];
		self.loadingMessage2.text = [messages objectAtIndexSafe:3];
	} else {
		self.loadingTitle1.text = @"";
		self.loadingMessage1.text = @"";
		self.loadingTitle2.text = @"";
		self.loadingMessage2.text = @"";
	}	
}

- (void)setMessage1Text:(NSString *)message {
	self.loadingMessage1.text = message;
}

- (void)setMessage2Text:(NSString *)message {
	self.loadingMessage2.text = message;
}

- (void)hide {
	[self.view removeFromSuperview];
}

@end
