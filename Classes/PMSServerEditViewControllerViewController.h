//
//  PMSServerEditViewControllerViewController.h
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerTypeViewController.h"

@class PMSLoginLoader;
@interface PMSServerEditViewControllerViewController : UIViewController <ISMSLoaderDelegate>

@property (nonatomic, strong) PMSLoginLoader *loader;

@property (nonatomic, strong) IBOutlet UITextField *urlField;
@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIButton *saveButton;
@property (nonatomic, weak) ServerTypeViewController *parentController;
@property (nonatomic, copy) NSString *theNewRedirectUrl;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
