//
//  ChatViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatViewController.h"
#import "ChatUITableViewCell.h"
#import "ServerListViewController.h"
#import "CustomUITextView.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "ISMSErrorDomain.h"
#import "SUSChatDAO.h"
#import "ISMSChatMessage.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation ChatViewController

#pragma mark - Rotation

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	if (!UIDevice.isIPad && self.isNoChatMessagesScreenShowing) {
		if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation)) {
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
			self.noChatMessagesScreen.transform = translate;
		} else {
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, -160.0);
			self.noChatMessagesScreen.transform = translate;
		}
	}
}

#pragma mark Life Cycle

- (void)createDataModel {
	self.dataModel = [[SUSChatDAO alloc] initWithDelegate:self];
}

- (void)loadData {
	[self.dataModel startLoad];
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
}

- (void)cancelLoad {
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
	self.isNoChatMessagesScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Chat";

	// Create text input box in header
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 82)];
	self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.headerView.backgroundColor = ISMSHeaderColor;
	
	self.textInput = [[CustomUITextView alloc] initWithFrame:CGRectMake(5, 5, 240, 72)];
	self.textInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.textInput.font = ISMSRegularFont(16);
	self.textInput.delegate = self;
	[self.headerView addSubview:self.textInput];
	
	UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	sendButton.frame = CGRectMake(252, 11, 60, 60);
	sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[sendButton addTarget:self action:@selector(sendButtonAction) forControlEvents:UIControlEventTouchUpInside];
	[sendButton setImage:[UIImage imageNamed:@"comment-write.png"] forState:UIControlStateNormal];
	[sendButton setImage:[UIImage imageNamed:@"comment-write-pressed.png"] forState:UIControlStateHighlighted];
	[self.headerView addSubview:sendButton];
	
	self.tableView.tableHeaderView = self.headerView;

    // Add the pull to refresh view
    __weak ChatViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [weakSelf loadData];
    }];
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	[self createDataModel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated  {
    [super viewWillAppear:animated];
	
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
		
	[self loadData];
	
	[Flurry logEvent:@"ChatTab"];
}

- (void)viewWillDisappear:(BOOL)animated {
	if (self.isNoChatMessagesScreenShowing == YES) {
		[self.noChatMessagesScreen removeFromSuperview];
		self.isNoChatMessagesScreenShowing = NO;
	}
}

- (void)showNoChatMessagesScreen {
	if (!self.isNoChatMessagesScreenShowing) {
		self.isNoChatMessagesScreenShowing = YES;
		self.noChatMessagesScreen = [[UIImageView alloc] init];
		self.noChatMessagesScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		self.noChatMessagesScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noChatMessagesScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noChatMessagesScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.noChatMessagesScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		[textLabel setText:@"No Chat Messages\non the\nServer"];
		textLabel.frame = CGRectMake(15, 15, 210, 150);
		[self.noChatMessagesScreen addSubview:textLabel];
		
		[self.view addSubview:self.noChatMessagesScreen];
		
		if (!UIDevice.isIPad) {
			if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
				CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
				CGAffineTransform scale = CGAffineTransformMakeScale(0.75, 0.75);
				self.noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			}
		}
	}
}

#pragma mark Button handling

- (void) settingsAction:(id)sender {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark ISMSLoader delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self.refreshControl endRefreshing];
	
	if (error.code == ISMSErrorCode_CouldNotSendChatMessage) {
		self.textInput.text = [[[error userInfo] objectForKey:@"message"] copy];
	}
}

- (void)loadingFinished:(SUSLoader *)theLoader {
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self.refreshControl endRefreshing];
}

#pragma mark UITextView delegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
	// Create overlay
	self.chatMessageOverlay = [[UIView alloc] init];
    if (UIDevice.isIPad) {
		self.chatMessageOverlay.frame = CGRectMake(0, 82, 1024, 1024);
    } else {
		self.chatMessageOverlay.frame = CGRectMake(0, 82, 480, 480);
    }
    
	self.chatMessageOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.chatMessageOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	self.chatMessageOverlay.alpha = 0.0;
	[self.view addSubview:self.chatMessageOverlay];
	
	self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.dismissButton addTarget:self action:@selector(doneSearching_Clicked:) forControlEvents:UIControlEventTouchUpInside];
	self.dismissButton.frame = self.view.bounds;
	self.dismissButton.enabled = NO;
	[self.chatMessageOverlay addSubview:self.dismissButton];
	
	// Animate the segmented control on screen
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.chatMessageOverlay.alpha = 1;
        self.dismissButton.enabled = YES;
    } completion:nil];
    
	//Add the done button.
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
	// Animate the segmented control off screen
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.chatMessageOverlay.alpha = 0;
        self.dismissButton.enabled = NO;
    } completion:nil];
}

- (void) doneSearching_Clicked:(id)sender  {
	[self.textInput resignFirstResponder];
	
	if(musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
}

#pragma mark Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath  {
	// Automatically set the height based on the height of the message text
	ISMSChatMessage *aChatMessage = [self.dataModel.chatMessages objectAtIndexSafe:indexPath.row];
    CGSize expectedLabelSize = [aChatMessage.message boundingRectWithSize:CGSizeMake(310,CGFLOAT_MAX)
                                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                                               attributes:@{NSFontAttributeName:ISMSRegularFont(20)}
                                                                  context:nil].size;
    if (expectedLabelSize.height < 40) {
		expectedLabelSize.height = 40;
    }
	return (expectedLabelSize.height + 20);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataModel.chatMessages.count;
}

- (NSString *)formatDate:(NSInteger)unixtime {
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:unixtime];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = kCFDateFormatterShortStyle;
	formatter.timeStyle = kCFDateFormatterShortStyle;
	formatter.locale = [NSLocale currentLocale];
	NSString *formattedDate = [formatter stringFromDate:date];
	
	return formattedDate;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"ChatCell";
	ChatUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell) {
		cell = [[ChatUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}

	ISMSChatMessage *aChatMessage = [self.dataModel.chatMessages objectAtIndexSafe:indexPath.row];
	cell.userNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aChatMessage.user, [self formatDate:aChatMessage.timestamp]];
	cell.messageLabel.text = aChatMessage.message;
		
    return cell;
}

- (void)sendButtonAction {
	if ([self.textInput.text length] != 0) {
		[self.textInput resignFirstResponder];

		if (musicS.showPlayerIcon) {
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
		} else {
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Sending"];
		[self.dataModel sendChatMessage:self.textInput.text];
		
		self.textInput.text = @"";
		[self.textInput resignFirstResponder];
	}
}

- (void)dealloc  {
	self.dataModel.delegate = nil;
}

@end
