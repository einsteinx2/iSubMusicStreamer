//
//  LoadingScreen.h
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface LoadingScreen : UIViewController

@property (strong) UIButton *inputBlocker;
@property (strong) UIImageView *loadingScreenRectangle;
@property (strong) UILabel *loadingLabel;
@property (strong) UILabel *loadingTitle1;
@property (strong) UILabel *loadingMessage1;
@property (strong) UILabel *loadingTitle2;
@property (strong) UILabel *loadingMessage2;
@property (strong) UIActivityIndicatorView *activityIndicator;


- (id)initOnView:(UIView *)view withMessage:(NSArray *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow; 
//- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow;
- (void)setAllMessagesText:(NSArray *)messages;
- (void)setMessage1Text:(NSString *)message;
- (void)setMessage2Text:(NSString *)message;
- (void)hide;

- (IBAction)inputBlockerAction:(id)sender;

@end
