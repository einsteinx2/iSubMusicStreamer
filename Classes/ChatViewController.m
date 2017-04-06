//
//  ChatViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatViewController.h"
#import "ChatUITableViewCell.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "EGORefreshTableHeaderView.h"

@interface ChatViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
@end


@implementation ChatViewController

@synthesize noChatMessagesScreen, chatMessages, lastCheck;
@synthesize isReloading;
@synthesize dataModel;
@synthesize isNoChatMessagesScreenShowing;
@synthesize headerView, textInput, chatMessageOverlay, dismissButton;
@synthesize receivedData, refreshHeaderView;

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (!IS_IPAD() && self.isNoChatMessagesScreenShowing)
	{
		if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
		{
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
			self.noChatMessagesScreen.transform = translate;
		}
		else
		{
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, -160.0);
			self.noChatMessagesScreen.transform = translate;
		}
	}
}

#pragma mark - Life Cycle

- (void)createDataModel
{
	self.dataModel = [[SUSChatDAO alloc] initWithDelegate:self];
}

- (void)loadData
{
	[self.dataModel startLoad];
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
}

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
    if (IS_IOS7())
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
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
	self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	self.refreshHeaderView.backgroundColor = [UIColor whiteColor];
	[self.tableView addSubview:self.refreshHeaderView];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}

	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	
	[self createDataModel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
    [self addURLRefBackButton];
    
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
		
	[self loadData];
	
	[Flurry logEvent:@"ChatTab"];
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (isNoChatMessagesScreenShowing == YES)
	{
		[noChatMessagesScreen removeFromSuperview];
		isNoChatMessagesScreenShowing = NO;
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)showNoChatMessagesScreen
{
	if (!self.isNoChatMessagesScreenShowing)
	{
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
		
		
		if (!IS_IPAD())
		{
			if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
				CGAffineTransform scale = CGAffineTransformMakeScale(0.75, 0.75);
				self.noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			}
		}
	}
}

#pragma mark - Button handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
	
	if (error.code == ISMSErrorCode_CouldNotSendChatMessage)
	{
		self.textInput.text = [[[error userInfo] objectForKey:@"message"] copy];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - UITextView delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	// Create overlay
	self.chatMessageOverlay = [[UIView alloc] init];
	if (IS_IPAD())
		self.chatMessageOverlay.frame = CGRectMake(0, 82, 1024, 1024);
	else
		self.chatMessageOverlay.frame = CGRectMake(0, 82, 480, 480);
	
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
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	self.chatMessageOverlay.alpha = 1;
	self.dismissButton.enabled = YES;
	[UIView commitAnimations];
	
	
	//Add the done button.
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
	// Animate the segmented control off screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	self.chatMessageOverlay.alpha = 0;
	self.dismissButton.enabled = NO;
	[UIView commitAnimations];
}


- (void) doneSearching_Clicked:(id)sender 
{	
	[self.textInput resignFirstResponder];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Automatically set the height based on the height of the message text
	ISMSChatMessage *aChatMessage = [dataModel.chatMessages objectAtIndexSafe:indexPath.row];
    CGSize expectedLabelSize = [aChatMessage.message boundingRectWithSize:CGSizeMake(310,CGFLOAT_MAX)
                                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                                               attributes:@{NSFontAttributeName:ISMSRegularFont(20)}
                                                                  context:nil].size;
	if (expectedLabelSize.height < 40)
		expectedLabelSize.height = 40;
	return (expectedLabelSize.height + 20);
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [dataModel.chatMessages count];
}


- (NSString *)formatDate:(NSInteger)unixtime
{
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:unixtime];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = kCFDateFormatterShortStyle;
	formatter.timeStyle = kCFDateFormatterShortStyle;
	formatter.locale = [NSLocale currentLocale];
	NSString *formattedDate = [formatter stringFromDate:date];
	
	return formattedDate;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"ChatCell";
	ChatUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[ChatUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}

    // Set up the cell...
	ISMSChatMessage *aChatMessage = [dataModel.chatMessages objectAtIndexSafe:indexPath.row];
	cell.userNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aChatMessage.user, [self formatDate:aChatMessage.timestamp]];
	cell.messageLabel.text = aChatMessage.message;
	
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
    return cell;
}


- (void)sendButtonAction
{
	if ([self.textInput.text length] != 0)
	{
		[self.textInput resignFirstResponder];

		if(musicS.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Sending"];
		[self.dataModel sendChatMessage:self.textInput.text];
		
		self.textInput.text = @"";
		[self.textInput resignFirstResponder];
	}
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.isReloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.isReloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !self.isReloading) 
	{
		self.isReloading = YES;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self loadData];
		[self.refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	self.isReloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[self.refreshHeaderView setState:EGOOPullRefreshNormal];
}

- (void)dealloc 
{
	self.dataModel.delegate = nil;
}


@end

