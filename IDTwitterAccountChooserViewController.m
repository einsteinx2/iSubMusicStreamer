//
//  IDTwitterAccountChooserViewController.m
//  AngelFon
//
//  Created by Carlos Oliva on 05-12-12.
//  Copyright (c) 2012 iDev Software. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <Twitter/Twitter.h>
#import "IDTwitterAccountChooserViewController.h"

#define kTwitterAPIRootURL @"https://api.twitter.com/1.1/"

@interface IDTwitterAccountChooserContentViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *tableView;
	NSArray *twitterAccounts;
	__weak id <IDTwitterAccountChooserViewControllerDelegate> accountChooserDelegate;
	NSMutableDictionary *imagesDictionary;
	NSMutableDictionary *realNamesDictionary;
	IDTwitterAccountChooserViewControllerCompletionHandler completionHandler;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *twitterAccounts;
@property (nonatomic, weak) id <IDTwitterAccountChooserViewControllerDelegate> accountChooserDelegate;
@property (nonatomic, copy) IDTwitterAccountChooserViewControllerCompletionHandler completionHandler;

@end


@implementation IDTwitterAccountChooserContentViewController

@synthesize tableView;
@synthesize twitterAccounts;
@synthesize accountChooserDelegate;
@synthesize completionHandler;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if(self) {
		imagesDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
		realNamesDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
	}
	return self;
}


- (void)loadView {
	self.view = self.tableView;
}


- (void)viewDidLoad {
	self.navigationItem.title = NSLocalizedString(@"Choose an Account", @"Choose an Account");
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																						  target:self
																						  action:@selector(cancel:)];
}


- (void)viewDidAppear:(BOOL)animated {
	[self loadMetadataForCellsWithIndexPaths:[self.tableView indexPathsForVisibleRows]];
}


- (void)viewDidUnload {
	[super viewDidUnload];
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[imagesDictionary removeAllObjects];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}


- (void)loadMetadataForCellsWithIndexPaths:(NSArray *)indexPaths {
    return;// This is broken on iOS 5 apparantly so fuck it
    
//	for(NSIndexPath *indexPath in indexPaths) {
//		ACAccount *account = [self.twitterAccounts objectAtIndex:indexPath.row];
//		NSString *username = [account username];
//		if(username == nil || ([imagesDictionary objectForKey:username] != nil && [realNamesDictionary objectForKey:username] != nil))
//			continue;
//		NSURL *url = [NSURL URLWithString:[kTwitterAPIRootURL stringByAppendingString:@"users/show.json"]];
//		NSDictionary *parameters = @{
//			@"screen_name": username
//		};
//		TWRequest *request = [[TWRequest alloc] initWithURL:url
//												 parameters:parameters
//											  requestMethod:TWRequestMethodGET];
//		[request setAccount:account];
//		[request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
//			if(error != nil && responseData == nil) {
//				NSLog(@"TWRequest error: %@", [error localizedDescription]);
//				return;
//			}
//			error = nil;
//			NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
//			if(error != nil) {
//				NSLog(@"JSON deserialization error: %@", [error localizedDescription]);
//				return;
//			}
//			NSString *name = [responseDictionary objectForKey:@"name"];
//			if([realNamesDictionary objectForKey:username] == nil && name != nil) {
//				dispatch_async(dispatch_get_main_queue(), ^{
//					[realNamesDictionary setObject:name forKey:username];
//					[self.tableView reloadData];
//				});
//			}
//			NSString *profileImageURLString = [responseDictionary objectForKey:@"profile_image_url"];
//			if([imagesDictionary objectForKey:username] == nil && profileImageURLString != nil) {
//				NSString *filename = [[profileImageURLString componentsSeparatedByString:@"/"] lastObject];
//				NSString *extension = [filename pathExtension];
//				NSString *basename = [filename stringByDeletingPathExtension];
//				NSString *biggerFilename = [[basename stringByReplacingOccurrencesOfString:@"normal" withString:@"bigger" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(0, [basename length])] stringByAppendingPathExtension:extension];
//				NSString *biggerFilenameURLString = [profileImageURLString stringByReplacingOccurrencesOfString:filename
//																									 withString:biggerFilename
//																										options:(NSAnchoredSearch | NSBackwardsSearch)
//																										  range:NSMakeRange(0, [profileImageURLString length])];
//				NSURL *imageURL = [NSURL URLWithString:biggerFilenameURLString];
//				TWRequest *imageRequest = [[TWRequest alloc] initWithURL:imageURL
//															  parameters:nil
//														   requestMethod:TWRequestMethodGET];
//				[imageRequest setAccount:account];
//				[imageRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
//					if(error != nil && responseData == nil) {
//						NSLog(@"TWRequest error: %@", [error localizedDescription]);
//						return;
//					}
//					UIImage *biggerImage = [UIImage imageWithData:responseData];
//					UIImage *image = [UIImage imageWithCGImage:[biggerImage CGImage]
//														 scale:2.0
//												   orientation:UIImageOrientationUp];
//					if([imagesDictionary objectForKey:username] == nil) {
//						dispatch_async(dispatch_get_main_queue(), ^{
//							[imagesDictionary setObject:image forKey:username];
//							[self.tableView reloadData];
//						});
//					}
//				}];
//				
//			}
//		}];
//	}
}


#pragma mark - Button Actions


- (IBAction)cancel:(id)sender {
	[self dismissViewControllerAnimated:YES completion:^{
		if(completionHandler != nil) {
			completionHandler(nil);
			return;
		}
		if(self.accountChooserDelegate != nil && [self.accountChooserDelegate conformsToProtocol:@protocol(IDTwitterAccountChooserViewControllerDelegate)] &&
		   [self.accountChooserDelegate respondsToSelector:@selector(twitterAccountChooserViewController:didChooseTwitterAccount:)]) {
			[self.accountChooserDelegate twitterAccountChooserViewController:(IDTwitterAccountChooserViewController *)self.navigationController didChooseTwitterAccount:nil];
		}
	}];
}


#pragma mark - Getter Methods


- (UITableView *)tableView {
	if(tableView == nil) {
		tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] bounds] style:UITableViewStyleGrouped];
		tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		tableView.autoresizesSubviews = YES;
		tableView.delegate = self;
		tableView.dataSource = self;
	}
	return tableView;
}


#pragma mark - <UITableViewDataSource> Methods


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.twitterAccounts count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"cell";
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
	if(cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	ACAccount *account = [self.twitterAccounts objectAtIndex:indexPath.row];
//	NSDictionary *properties = [account valueForKey:@"properties"];
//	if(properties != nil) {
//		NSLog(@"properties: %@", properties);
//	}
	NSString *username = [account username];
	cell.textLabel.text = [account accountDescription];
	
	NSString *realName = [realNamesDictionary objectForKey:username];
	cell.detailTextLabel.text = realName;

	UIImage *image = [imagesDictionary objectForKey:username];
	[cell.imageView setImage:image];

	return cell;
}


#pragma mark - <UITableViewDelegate> Methods


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self dismissViewControllerAnimated:YES completion:^{
		ACAccount *account = [self.twitterAccounts objectAtIndex:indexPath.row];
		if(completionHandler != nil) {
			completionHandler(account);
			return;
		}
		if(self.accountChooserDelegate != nil && [self.accountChooserDelegate conformsToProtocol:@protocol(IDTwitterAccountChooserViewControllerDelegate)] &&
		   [self.accountChooserDelegate respondsToSelector:@selector(twitterAccountChooserViewController:didChooseTwitterAccount:)]) {
			[self.accountChooserDelegate twitterAccountChooserViewController:(IDTwitterAccountChooserViewController *)self.navigationController didChooseTwitterAccount:account];
		}
	}];
}


- (void)scrollViewDidEndDecelerating:(UITableView *)tableView {
	[self loadMetadataForCellsWithIndexPaths:[self.tableView indexPathsForVisibleRows]];
}


- (void)scrollViewDidEndDragging:(UITableView *)tableView willDecelerate:(BOOL)decelerate {
	if(!decelerate)
		[self loadMetadataForCellsWithIndexPaths:[self.tableView indexPathsForVisibleRows]];
}


- (void)scrollViewDidScrollToTop:(UITableView *)tableView {
	[self loadMetadataForCellsWithIndexPaths:[self.tableView indexPathsForVisibleRows]];
}



@end


#pragma mark -


@interface IDTwitterAccountChooserViewController () {
	IDTwitterAccountChooserContentViewController *contentViewController;
}

@property (nonatomic, strong, readonly) IDTwitterAccountChooserContentViewController *contentViewController;

@end


@implementation IDTwitterAccountChooserViewController

@synthesize contentViewController;


- (id)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super initWithRootViewController:[[IDTwitterAccountChooserContentViewController alloc] init]];
    if (self) {
        // Custom initialization
    }
    return self;
}


#pragma mark - Forwarded Methods


- (void)setTwitterAccounts:(NSArray *)twitterAccounts {
	[self.contentViewController setTwitterAccounts:twitterAccounts];
}


- (void)setAccountChooserDelegate:(id <IDTwitterAccountChooserViewControllerDelegate>)delegate {
	[self.contentViewController setAccountChooserDelegate:delegate];
}


- (void)setCompletionHandler:(IDTwitterAccountChooserViewControllerCompletionHandler)completionHandler {
	[self.contentViewController setCompletionHandler:completionHandler];
}


#pragma mark - Getter Methods


- (IDTwitterAccountChooserContentViewController *)contentViewController {
	if([self.viewControllers count] == 0)
		return nil;
	return [self.viewControllers objectAtIndex:0];
}


@end
