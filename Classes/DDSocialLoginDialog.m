//
//  DDSocialLoginDialog.m
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

#import "DDSocialLoginDialog.h"

@interface DDSocialLoginDialog ()
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, readonly) UITextField *usernameField;
@property (nonatomic, readonly) UITextField *passwordField;
@end

@implementation DDSocialLoginDialog

@synthesize username = username_;
@synthesize password = password_;
@synthesize delegate = delegate_;
@dynamic usernameField;
@dynamic passwordField;

- (id)initWithDelegate:(id)delegate theme:(DDSocialDialogTheme)theme {

	// Hardcode the dialog CGSize to {250, 210}, especially optimized for iPhone landscape view.
    if ((self = [super initWithFrame:CGRectMake(0, 0, 250, 210) theme:theme])) {
		// DDSocialLoginDialogDelegate
		delegate_ = delegate;
		// DDSocialDialogDelegate, so you can use -socialDialogDidSucceed:(socialDialog *) when user cancel the dialog. This is optional.
		self.dialogDelegate = delegate;
				
		// Setup title
		switch (theme) {
			case DDSocialDialogThemePlurk:
				self.titleLabel.text = NSLocalizedString(@"Plurk Login", nil);
				break;
			case DDSocialDialogThemeTwitter:
			default:
				self.titleLabel.text = NSLocalizedString(@"Twitter Login", nil);
				break;
		}
		
		tableView_ = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		tableView_.delegate = self;
		tableView_.dataSource = self;
		tableView_.scrollEnabled = NO;
		tableView_.backgroundColor = [UIColor whiteColor];
		[self.contentView addSubview:tableView_];
	}
    return self;
}

- (void)dealloc {
	
	delegate_ = nil;
	username_ = nil;
	password_ = nil;
	
	usernameField_.delegate = nil;
	usernameField_ = nil;
	passwordField_.delegate = nil;
	passwordField_ = nil;
	tableView_.delegate = nil;
	tableView_.dataSource = nil;
	tableView_ = nil;
}

#pragma mark -
#pragma mark layout

- (void)layoutSubviews {
	[super layoutSubviews];
	
	tableView_.frame = self.contentView.bounds;
}

- (void)show {
	
	// Call super first to setup dialog before adding your stuffs
	[super show];	
	[self setNeedsLayout];
}

#pragma mark -

- (UITextField *)usernameField {
	if (usernameField_ == nil) {
		usernameField_ = [[UITextField alloc] initWithFrame:CGRectMake(8., 0., tableView_.frame.size.width - 28., 34.)];
		usernameField_.delegate = self;
		usernameField_.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		usernameField_.clearButtonMode = UITextFieldViewModeWhileEditing;
		usernameField_.placeholder = NSLocalizedString(@"Username or email", nil);
	} 
		
	return usernameField_;
}

- (UITextField *)passwordField {
	if (passwordField_ == nil) {
		passwordField_ = [[UITextField alloc] initWithFrame:CGRectMake(8., 0., tableView_.frame.size.width - 28., 34.)];
		passwordField_.delegate = self;
		passwordField_.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		passwordField_.clearButtonMode = UITextFieldViewModeWhileEditing;
		passwordField_.placeholder = NSLocalizedString(@"Password", nil);
		passwordField_.secureTextEntry = YES;	
	} 
	
	return passwordField_;	
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		return 2;
	}
	
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"LoginCell";
    
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
	
	if (indexPath.section == 0) {
		for (UIView *subview in cell.contentView.subviews) {
			[subview removeFromSuperview];
		}
		if (indexPath.row == 0) {
			self.usernameField.tag = indexPath.row;
			[cell.contentView addSubview:self.usernameField];
		} else {
			self.passwordField.tag = indexPath.row;
			[cell.contentView addSubview:self.passwordField];
		}		
	} else {
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.textLabel.text = NSLocalizedString(@"Sign In", nil);
	}
    
    return cell;
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		return 34.;
	}
	
	return 30.;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 1) {		
		self.username = self.usernameField.text;
		self.password = self.passwordField.text;

		if ([delegate_ conformsToProtocol:@protocol(DDSocialLoginDialogDelegate)]) {
			if ([delegate_ respondsToSelector:@selector(socialDialogDidSucceed:)]) {
				[delegate_ socialDialogDidSucceed:self];
			}		
		}
		
		[self dismiss:YES];
	}	
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField.tag == 0) {
		[self.passwordField becomeFirstResponder];
	} else {
		[self.usernameField becomeFirstResponder];
	}		
	
	return YES;
}

@end
