//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@interface SubsonicServerEditViewController : UIViewController <SUSLoaderDelegate>

@property (nonatomic, strong) IBOutlet UITextField *urlField;
@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIButton *saveButton;

- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;

@end
